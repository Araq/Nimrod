#
#
#           The Nim Compiler
#        (c) Copyright 2012 Andreas Rumpf
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

## This module implements the passes functionality. A pass must implement the
## `TPass` interface.

import

  options, ast, llstream, msgs, idents, syntaxes, idgen, modulegraphs,
  reorder, lineinfos, pathutils, ic

type
  TPassData* = tuple[input: PNode, closeOutput: PNode]

# a pass is a tuple of procedure vars ``TPass.close`` may produce additional
# nodes. These are passed to the other close procedures.
# This mechanism used to be used for the instantiation of generics.

proc makePass*(open: TPassOpen = nil,
               process: TPassProcess = nil,
               close: TPassClose = nil,
               isFrontend = false): TPass =
  result.open = open
  result.close = close
  result.process = process
  result.isFrontend = isFrontend

proc skipCodegen*(config: ConfigRef; n: PNode): bool {.inline.} =
  # can be used by codegen passes to determine whether they should do
  # something with `n`. Currently, this ignores `n` and uses the global
  # error count instead.
  result = config.errorCounter > 0
  # no point in even attempting codegen on a nil pnode
  result = result or n == nil
  when not defined(release):
    if n == nil:
      raise newException(Defect, "why?")

const
  maxPasses = 10

type
  TPassContextArray = array[0..maxPasses - 1, PPassContext]

proc clearPasses*(g: ModuleGraph) =
  g.passes.setLen(0)

proc registerPass*(g: ModuleGraph; p: TPass) =
  internalAssert g.config, g.passes.len < maxPasses
  g.passes.add(p)

proc carryPass*(g: ModuleGraph; p: TPass, module: PSym;
                m: TPassData): TPassData =
  var c = p.open(g, module)
  result.input = p.process(c, m.input)
  result.closeOutput = if p.close != nil: p.close(g, c, m.closeOutput)
                       else: m.closeOutput

proc carryPasses*(g: ModuleGraph; nodes: PNode, module: PSym;
                  passes: openArray[TPass]) =
  var passdata: TPassData
  passdata.input = nodes
  for pass in passes:
    passdata = carryPass(g, pass, module, passdata)

proc openPasses(g: ModuleGraph; a: var TPassContextArray;
                module: PSym) =
  for i in 0..<g.passes.len:
    if not isNil(g.passes[i].open):
      a[i] = g.passes[i].open(g, module)
    else: a[i] = nil

proc closePasses(graph: ModuleGraph; a: var TPassContextArray) =
  var m: PNode = nil
  for i in 0..<graph.passes.len:
    if not isNil(graph.passes[i].close): m = graph.passes[i].close(graph, a[i], m)
    a[i] = nil                # free the memory here

proc processTopLevelStmt(graph: ModuleGraph, n: PNode, a: var TPassContextArray): bool =
  # this implements the code transformation pipeline
  compileUncachedIt(graph, n):
    var
      m: PNode = it
    block prematureEvacuation:
      for i in 0..<graph.passes.len:
        if graph.passes[i].process != nil:
          m = graph.passes[i].process(a[i], m)
          if m == nil:
            break prematureEvacuation
      result = true

proc resolveMod(conf: ConfigRef; module, relativeTo: string): FileIndex =
  let fullPath = findModule(conf, module, relativeTo)
  if fullPath.isEmpty:
    result = InvalidFileIdx
  else:
    result = fileInfoIdx(conf, fullPath)

proc processImplicits(graph: ModuleGraph; implicits: seq[string], nodeKind: TNodeKind,
                      a: var TPassContextArray; m: PSym) =
  # XXX fixme this should actually be relative to the config file!
  let relativeTo = toFullPath(graph.config, m.info)
  for module in items(implicits):
    # implicit imports should not lead to a module importing itself
    if m.position != resolveMod(graph.config, module, relativeTo).int32:
      var importStmt = newNodeI(nodeKind, m.info)
      var str = newStrNode(nkStrLit, module)
      str.info = m.info
      importStmt.add str
      if not processTopLevelStmt(graph, importStmt, a): break

const
  imperativeCode = {low(TNodeKind)..high(TNodeKind)} - {nkTemplateDef, nkProcDef, nkMethodDef,
    nkMacroDef, nkConverterDef, nkIteratorDef, nkFuncDef, nkPragma,
    nkExportStmt, nkExportExceptStmt, nkFromStmt, nkImportStmt, nkImportExceptStmt}

proc prepareConfigNotes(graph: ModuleGraph; module: PSym) =
  if sfMainModule in module.flags:
    graph.config.mainPackageId = module.owner.id
  # don't be verbose unless the module belongs to the main package:
  if module.owner.id == graph.config.mainPackageId:
    graph.config.notes = graph.config.mainPackageNotes
  else:
    if graph.config.mainPackageNotes == {}: graph.config.mainPackageNotes = graph.config.notes
    graph.config.notes = graph.config.foreignPackageNotes

proc moduleHasChanged*(graph: ModuleGraph; module: PSym): bool {.inline.} =
  result = module.id >= 0 or isDefined(graph.config, "nimBackendAssumesChange")

proc processCachedModule*(graph: ModuleGraph; module: PSym;
                          stream: PLLStream) =
  var
    p: TParsers
    a: TPassContextArray
    s: PLLStream
    fileIdx = module.fileIdx

  # new module caching mechanism:
  for i in 0..<graph.passes.len:
    if not isNil(graph.passes[i].open) and not graph.passes[i].isFrontend:
      a[i] = graph.passes[i].open(graph, module)
    else:
      a[i] = nil

  if not graph.stopCompile():
    compileCachedIt(graph, module):
      var m = it
      for i in 0..<graph.passes.len:
        if not isNil(graph.passes[i].process) and not graph.passes[i].isFrontend:
          m = graph.passes[i].process(a[i], m)
          if isNil(m):
            break

  var m: PNode = nil
  for i in 0..<graph.passes.len:
    if not isNil(graph.passes[i].close) and not graph.passes[i].isFrontend:
      m = graph.passes[i].close(graph, a[i], m)
    a[i] = nil

proc processUncachedModule*(graph: ModuleGraph; module: PSym;
                            stream: PLLStream) =
  var
    p: TParsers
    a: TPassContextArray
    s: PLLStream
    fileIdx = module.fileIdx

  openPasses(graph, a, module)
  if stream == nil:
    let filename = toFullPathConsiderDirty(graph.config, fileIdx)
    s = llStreamOpen(filename, fmRead)
    if s == nil:
      rawMessage(graph.config, errCannotOpenFile, filename.string)
      return
  else:
    s = stream

  while true:
    # open the parsers on every pass; ie. read streaming data from stdin
    openParsers(p, fileIdx, s, graph.cache, graph.config)
    if module.owner == nil or module.owner.name.s != "stdlib" or module.name.s == "distros":
      # TODO what about caching? no processing then? what if I change the
      # modules to include between compilation runs? we'd need to track that
      # in ROD files. I think we should enable this feature only
      # for the interactive mode.
      if module.name.s != "nimscriptapi":
        processImplicits(graph, graph.config.implicitImports, nkImportStmt,
                         a, module)
        processImplicits(graph, graph.config.implicitIncludes, nkIncludeStmt,
                         a, module)

    while true:
      # this is we consume chunks of toplevel statements
      if graph.stopCompile(): break
      # parse it
      var n = parseTopLevelStmt(p)
      if n.kind == nkEmpty: break
      # if it's something that should be reordered...
      if (sfSystemModule notin module.flags and
          ({sfNoForward, sfReorder} * module.flags != {} or
          codeReordering in graph.config.features)):
        # read everything, no streaming possible
        var sl = newNodeI(nkStmtList, n.info)
        sl.add n
        while true:
          # keep iterating on every toplevel chunk
          var n = parseTopLevelStmt(p)
          if n.kind == nkEmpty: break
          sl.add n
        if sfReorder in module.flags or codeReordering in graph.config.features:
          sl = reorder(graph, sl, module)
        discard processTopLevelStmt(graph, sl, a)
        break
      # else we'll consume as just another chunk
      elif n.kind in imperativeCode:
        # read everything until the next proc declaration etc.
        var sl = newNodeI(nkStmtList, n.info)
        sl.add n
        var rest: PNode = nil
        while true:
          # keep iterating on every toplevel chunk
          var n = parseTopLevelStmt(p)
          if n.kind == nkEmpty or n.kind notin imperativeCode:
            # if it found a reordered bit, then stash it and break out
            rest = n
            break
          # adding it to the statement list
          sl.add n
        #echo "-----\n", sl
        # consume that entire list of the toplevel statements
        if not processTopLevelStmt(graph, sl, a): break
        # if there was some reordered stuff, consume that here
        if rest != nil:
          #echo "-----\n", rest
          if not processTopLevelStmt(graph, rest, a): break
      else:
        # super-naive consume whatever is held in the node only
        #echo "----- single\n", n
        if not processTopLevelStmt(graph, n, a): break

    closeParsers(p)
    if s.kind != llsStdIn: break

  closePasses(graph, a)
  # id synchronization point for more consistent code generation:
  idSynchronizationPoint(1000)

proc processModule*(graph: ModuleGraph; module: PSym, stream: PLLStream) =
  # if we're starting with stopping, then we're done
  if graph.stopCompile():
    return

  # otherwise, uh, prepare config notes
  prepareConfigNotes(graph, module)

  # negative module ids suggest cached modules or something
  if module.id < 0:
    # so give them a separate process
    echo "process cached ", module.name.s
    processCachedModule(graph, module, stream)
  else:
    # otherwise, just process the module normally
    processUncachedModule(graph, module, stream)
