#
#
#           The Nim Compiler
#        (c) Copyright 2020 Andreas Rumpf
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

import std / [hashes, tables, intsets, sha1]
import packed_ast, bitabs, rodfiles
import ".." / [ast, idents, lineinfos, msgs, ropes, options,
  sighashes, pathutils, condsyms]

from std / os import removeFile, isAbsolute

when not defined(release): import ".." / astalgo # debug()

type
  PackedConfig* = object
    backend: TBackend
    selectedGC: TGCMode
    cCompiler: TSystemCC
    options: TOptions
    globalOptions: TGlobalOptions

  ModuleStatus* = enum
    undefined,
    loading,
    loaded,
    outdated

  PackedModule* = object ## the parts of a PackedEncoder that are part of the .rod file
    status: ModuleStatus
    definedSymbols: string
    includes: seq[(LitId, string)] # first entry is the module filename itself
    imports: seq[LitId] # the modules this module depends on
    topLevel*: PackedTree  # top level statements
    bodies*: PackedTree # other trees. Referenced from typ.n and sym.ast by their position.
    hidden*: PackedTree # instantiated generics and other trees not directly in the source code.
    #producedGenerics*: Table[GenericKey, SymId]
    sh*: Shared
    cfg: PackedConfig

  PackedEncoder* = object
    m: PackedModule
    thisModule*: int32
    lastFile*: FileIndex # remember the last lookup entry.
    lastLit*: LitId
    filenames*: Table[FileIndex, LitId]
    pendingTypes*: seq[PType]
    pendingSyms*: seq[PSym]
    typeMarker*: IntSet #Table[ItemId, TypeId]  # ItemId.item -> TypeId
    symMarker*: IntSet #Table[ItemId, SymId]    # ItemId.item -> SymId
    config*: ConfigRef

template primConfigFields(fn: untyped) {.dirty.} =
  fn backend
  fn selectedGC
  fn cCompiler
  fn options
  fn globalOptions

proc definedSymbolsAsString(config: ConfigRef): string =
  result = newStringOfCap(200)
  result.add "config"
  for d in definedSymbolNames(config.symbols):
    result.add ' '
    result.add d

proc rememberConfig(c: var PackedEncoder; config: ConfigRef) =
  c.m.definedSymbols = definedSymbolsAsString(config)

  template rem(x) =
    c.m.cfg.x = config.x
  primConfigFields rem

proc configIdentical(m: PackedModule; config: ConfigRef): bool =
  result = m.definedSymbols == definedSymbolsAsString(config)
  template eq(x) =
    result = result and m.cfg.x == config.x
  primConfigFields eq

proc hashFileCached(conf: ConfigRef; fileIdx: FileIndex): string =
  result = msgs.getHash(conf, fileIdx)
  if result.len == 0:
    let fullpath = msgs.toFullPath(conf, fileIdx)
    result = $secureHashFile(fullpath)
    msgs.setHash(conf, fileIdx, result)

proc toLitId(x: FileIndex; c: var PackedEncoder): LitId =
  ## store a file index as a literal
  if x == c.lastFile:
    result = c.lastLit
  else:
    result = c.filenames.getOrDefault(x)
    if result == LitId(0):
      let p = msgs.toFullPath(c.config, x)
      result = getOrIncl(c.m.sh.strings, p)
      c.filenames[x] = result
    c.lastFile = x
    c.lastLit = result
    assert result != LitId(0)

proc toFileIndex(x: LitId; m: PackedModule; config: ConfigRef): FileIndex =
  result = msgs.fileInfoIdx(config, AbsoluteFile m.sh.strings[x])

proc includesIdentical(m: var PackedModule; config: ConfigRef): bool =
  for it in mitems(m.includes):
    if hashFileCached(config, toFileIndex(it[0], m, config)) != it[1]:
      return false
  result = true

proc initEncoder*(c: var PackedEncoder; m: PSym; config: ConfigRef) =
  ## setup a context for serializing to packed ast
  c.m.sh = Shared()
  c.thisModule = m.itemId.module
  c.config = config
  c.m.bodies = newTreeFrom(c.m.topLevel)
  c.m.hidden = newTreeFrom(c.m.topLevel)
  let thisNimFile = FileIndex c.thisModule
  c.m.includes.add((toLitId(thisNimFile, c), hashFileCached(config, thisNimFile))) # the module itself

proc addIncludeFileDep*(c: var PackedEncoder; f: FileIndex) =
  c.m.includes.add((toLitId(f, c), hashFileCached(c.config, f)))

proc addImportFileDep*(c: var PackedEncoder; f: FileIndex) =
  c.m.imports.add toLitId(f, c)

proc toPackedNode*(n: PNode; ir: var PackedTree; c: var PackedEncoder)
proc toPackedSym*(s: PSym; c: var PackedEncoder): PackedItemId
proc toPackedType(t: PType; c: var PackedEncoder): PackedItemId

proc flush(c: var PackedEncoder) =
  ## serialize any pending types or symbols from the context
  while true:
    if c.pendingTypes.len > 0:
      discard toPackedType(c.pendingTypes.pop, c)
    elif c.pendingSyms.len > 0:
      discard toPackedSym(c.pendingSyms.pop, c)
    else:
      break

proc toLitId(x: string; c: var PackedEncoder): LitId =
  ## store a string as a literal
  result = getOrIncl(c.m.sh.strings, x)

proc toLitId(x: BiggestInt; c: var PackedEncoder): LitId =
  ## store an integer as a literal
  result = getOrIncl(c.m.sh.integers, x)

proc toPackedInfo(x: TLineInfo; c: var PackedEncoder): PackedLineInfo =
  PackedLineInfo(line: x.line, col: x.col, file: toLitId(x.fileIndex, c))

proc safeItemId(s: PSym; c: var PackedEncoder): PackedItemId {.inline.} =
  ## given a symbol, produce an ItemId with the correct properties
  ## for local or remote symbols, packing the symbol as necessary
  if s == nil:
    result = nilItemId
  elif s.itemId.module == c.thisModule:
    result = PackedItemId(module: LitId(0), item: s.itemId.item)
  else:
    result = PackedItemId(module: toLitId(s.itemId.module.FileIndex, c),
                          item: s.itemId.item)

proc addModuleRef(n: PNode; ir: var PackedTree; c: var PackedEncoder) =
  ## add a remote symbol reference to the tree
  let info = n.info.toPackedInfo(c)
  ir.nodes.add PackedNode(kind: nkModuleRef, operand: 2.int32,  # 2 kids...
                          typeId: toPackedType(n.typ, c), info: info)
  ir.nodes.add PackedNode(kind: nkInt32Lit, info: info,
                          operand: toLitId(n.sym.itemId.module.FileIndex, c).int32)
  ir.nodes.add PackedNode(kind: nkInt32Lit, info: info,
                          operand: n.sym.itemId.item)

proc addMissing(c: var PackedEncoder; p: PSym) =
  ## consider queuing a symbol for later addition to the packed tree
  if p != nil and p.itemId.module == c.thisModule:
    if p.itemId.item notin c.symMarker:
      c.pendingSyms.add p

proc addMissing(c: var PackedEncoder; p: PType) =
  ## consider queuing a type for later addition to the packed tree
  if p != nil and p.uniqueId.module == c.thisModule:
    if p.uniqueId.item notin c.typeMarker:
      c.pendingTypes.add p

template storeNode(dest, src, field) =
  var nodeId: NodeId
  if src.field != nil:
    nodeId = getNodeId(c.m.bodies)
    toPackedNode(src.field, c.m.bodies, c)
  else:
    nodeId = emptyNodeId
  dest.field = nodeId

proc toPackedType(t: PType; c: var PackedEncoder): PackedItemId =
  ## serialize a ptype
  if t.isNil: return nilTypeId

  if t.uniqueId.module != c.thisModule:
    # XXX Assert here that it already was serialized in the foreign module!
    # it is a foreign type:
    return PackedItemId(module: toLitId(t.uniqueId.module.FileIndex, c), item: t.uniqueId.item)

  if not c.typeMarker.containsOrIncl(t.uniqueId.item):
    if t.uniqueId.item >= c.m.sh.types.len:
      setLen c.m.sh.types, t.uniqueId.item+1

    var p = PackedType(kind: t.kind, flags: t.flags, callConv: t.callConv,
      size: t.size, align: t.align, nonUniqueId: t.itemId.item,
      paddingAtEnd: t.paddingAtEnd, lockLevel: t.lockLevel)
    storeNode(p, t, n)

    for op, s in pairs t.attachedOps:
      c.addMissing s
      p.attachedOps[op] = s.safeItemId(c)

    p.typeInst = t.typeInst.toPackedType(c)
    for kid in items t.sons:
      p.types.add kid.toPackedType(c)
    for i, s in items t.methods:
      c.addMissing s
      p.methods.add (i, s.safeItemId(c))
    c.addMissing t.sym
    p.sym = t.sym.safeItemId(c)
    c.addMissing t.owner
    p.owner = t.owner.safeItemId(c)

    # fill the reserved slot, nothing else:
    c.m.sh.types[t.uniqueId.item] = p

  result = PackedItemId(module: LitId(0), item: t.uniqueId.item)

proc toPackedLib(l: PLib; c: var PackedEncoder): PackedLib =
  ## the plib hangs off the psym via the .annex field
  if l.isNil: return
  result.kind = l.kind
  result.generated = l.generated
  result.isOverriden = l.isOverriden
  result.name = toLitId($l.name, c)
  storeNode(result, l, path)

proc toPackedSym*(s: PSym; c: var PackedEncoder): PackedItemId =
  ## serialize a psym
  if s.isNil: return nilItemId

  if s.itemId.module != c.thisModule:
    # XXX Assert here that it already was serialized in the foreign module!
    # it is a foreign symbol:
    return PackedItemId(module: toLitId(s.itemId.module.FileIndex, c), item: s.itemId.item)

  if not c.symMarker.containsOrIncl(s.itemId.item):
    if s.itemId.item >= c.m.sh.syms.len:
      setLen c.m.sh.syms, s.itemId.item+1

    var p = PackedSym(kind: s.kind, flags: s.flags, info: s.info.toPackedInfo(c), magic: s.magic,
      position: s.position, offset: s.offset, options: s.options,
      name: s.name.s.toLitId(c))

    storeNode(p, s, ast)
    storeNode(p, s, constraint)

    if s.kind in {skLet, skVar, skField, skForVar}:
      c.addMissing s.guard
      p.guard = s.guard.safeItemId(c)
      p.bitsize = s.bitsize
      p.alignment = s.alignment

    p.externalName = toLitId(if s.loc.r.isNil: "" else: $s.loc.r, c)
    c.addMissing s.typ
    p.typ = s.typ.toPackedType(c)
    c.addMissing s.owner
    p.owner = s.owner.safeItemId(c)
    p.annex = toPackedLib(s.annex, c)
    when hasFFI:
      p.cname = toLitId(s.cname, c)

    # fill the reserved slot, nothing else:
    c.m.sh.syms[s.itemId.item] = p

  result = PackedItemId(module: LitId(0), item: s.itemId.item)

proc toSymNode(n: PNode; ir: var PackedTree; c: var PackedEncoder) =
  ## store a local or remote psym reference in the tree
  assert n.kind == nkSym
  template s: PSym = n.sym
  let id = s.toPackedSym(c).item
  if s.itemId.module == c.thisModule:
    # it is a symbol that belongs to the module we're currently
    # packing:
    ir.addSym(id, toPackedInfo(n.info, c))
  else:
    # store it as an external module reference:
    addModuleRef(n, ir, c)

proc toPackedNode*(n: PNode; ir: var PackedTree; c: var PackedEncoder) =
  ## serialize a node into the tree
  if n.isNil: return
  let info = toPackedInfo(n.info, c)
  case n.kind
  of nkNone, nkEmpty, nkNilLit, nkType:
    ir.nodes.add PackedNode(kind: n.kind, flags: n.flags, operand: 0,
                            typeId: toPackedType(n.typ, c), info: info)
  of nkIdent:
    ir.nodes.add PackedNode(kind: n.kind, flags: n.flags,
                            operand: int32 getOrIncl(c.m.sh.strings, n.ident.s),
                            typeId: toPackedType(n.typ, c), info: info)
  of nkSym:
    toSymNode(n, ir, c)
  of directIntLit:
    ir.nodes.add PackedNode(kind: n.kind, flags: n.flags,
                            operand: int32(n.intVal),
                            typeId: toPackedType(n.typ, c), info: info)
  of externIntLit:
    ir.nodes.add PackedNode(kind: n.kind, flags: n.flags,
                            operand: int32 getOrIncl(c.m.sh.integers, n.intVal),
                            typeId: toPackedType(n.typ, c), info: info)
  of nkStrLit..nkTripleStrLit:
    ir.nodes.add PackedNode(kind: n.kind, flags: n.flags,
                            operand: int32 getOrIncl(c.m.sh.strings, n.strVal),
                            typeId: toPackedType(n.typ, c), info: info)
  of nkFloatLit..nkFloat128Lit:
    ir.nodes.add PackedNode(kind: n.kind, flags: n.flags,
                            operand: int32 getOrIncl(c.m.sh.floats, n.floatVal),
                            typeId: toPackedType(n.typ, c), info: info)
  else:
    let patchPos = ir.prepare(n.kind, n.flags,
                              toPackedType(n.typ, c), info)
    for i in 0..<n.len:
      toPackedNode(n[i], ir, c)
    ir.patch patchPos

  when false:
    ir.flush c   # flush any pending types and symbols

proc toPackedNodeIgnoreProcDefs*(n: PNode, encoder: var PackedEncoder) =
  case n.kind
  of routineDefs:
    # we serialize n[namePos].sym instead
    if n[namePos].kind == nkSym:
      discard toPackedSym(n[namePos].sym, encoder)
    else:
      toPackedNode(n, encoder.m.topLevel, encoder)
  else:
    toPackedNode(n, encoder.m.topLevel, encoder)

proc toPackedNodeTopLevel*(n: PNode, encoder: var PackedEncoder) =
  toPackedNodeIgnoreProcDefs(n, encoder)
  flush encoder

proc storePrim*(f: var RodFile; x: PackedType) =
  for y in fields(x):
    when y is seq:
      storeSeq(f, y)
    else:
      storePrim(f, y)

proc loadPrim*(f: var RodFile; x: var PackedType) =
  for y in fields(x):
    when y is seq:
      loadSeq(f, y)
    else:
      loadPrim(f, y)

proc loadError(err: RodFileError; filename: AbsoluteFile) =
  echo "Error: ", $err, "\nloading file: ", filename.string

proc loadRodFile*(filename: AbsoluteFile; m: var PackedModule; config: ConfigRef): RodFileError =
  m.sh = Shared()
  var f = rodfiles.open(filename.string)
  f.loadHeader()
  f.loadSection configSection

  f.loadPrim m.definedSymbols
  f.loadPrim m.cfg

  if not configIdentical(m, config):
    f.err = configMismatch

  f.loadSection stringsSection
  f.load m.sh.strings

  f.loadSection checkSumsSection
  f.loadSeq m.includes
  if not includesIdentical(m, config):
    f.err = includeFileChanged

  f.loadSection depsSection
  f.loadSeq m.imports

  f.loadSection integersSection
  f.load m.sh.integers
  f.loadSection floatsSection
  f.load m.sh.floats

  f.loadSection topLevelSection
  f.loadSeq m.topLevel.nodes

  f.loadSection bodiesSection
  f.loadSeq m.bodies.nodes

  f.loadSection symsSection
  f.loadSeq m.sh.syms

  f.loadSection typesSection
  f.loadSeq m.sh.types

  close(f)
  result = f.err

type
  PackedModuleGraph* = seq[PackedModule] # indexed by FileIndex

proc needsRecompile(g: var PackedModuleGraph; conf: ConfigRef;
                    fileIdx: FileIndex): bool =
  let m = int(fileIdx)
  if m >= g.len:
    g.setLen(m+1)

  case g[m].status
  of undefined:
    g[m].status = loading
    let fullpath = msgs.toFullPath(conf, fileIdx)
    let rod = toRodFile(conf, AbsoluteFile fullpath)
    let err = loadRodFile(rod, g[m], conf)
    if err == ok:
      result = false
      # check its dependencies:
      for dep in g[m].imports:
        let fid = toFileIndex(dep, g[m], conf)
        # Warning: we need to traverse the full graph, so
        # do **not use break here**!
        if needsRecompile(g, conf, fid):
          result = true

      g[m].status = if result: outdated else: loaded
    else:
      loadError(err, rod)
      g[m].status = outdated
      result = true
  of loading, loaded:
    result = false
  of outdated:
    result = true

# -------------------------------------------------------------------------

proc storeError(err: RodFileError; filename: AbsoluteFile) =
  echo "Error: ", $err, "; couldn't write to ", filename.string
  removeFile(filename.string)

proc saveRodFile*(filename: AbsoluteFile; encoder: var PackedEncoder) =
  rememberConfig(encoder, encoder.config)

  var f = rodfiles.create(filename.string)
  f.storeHeader()
  f.storeSection configSection
  f.storePrim encoder.m.definedSymbols
  f.storePrim encoder.m.cfg

  f.storeSection stringsSection
  f.store encoder.m.sh.strings

  f.storeSection checkSumsSection
  f.storeSeq encoder.m.includes

  f.storeSection depsSection
  f.storeSeq encoder.m.imports

  f.storeSection integersSection
  f.store encoder.m.sh.integers

  f.storeSection floatsSection
  f.store encoder.m.sh.floats

  f.storeSection topLevelSection
  f.storeSeq encoder.m.topLevel.nodes

  f.storeSection bodiesSection
  f.storeSeq encoder.m.bodies.nodes

  f.storeSection symsSection
  f.storeSeq encoder.m.sh.syms

  f.storeSection typesSection
  f.storeSeq encoder.m.sh.types
  close(f)
  if f.err != ok:
    loadError(f.err, filename)

  when true:
    # basic loader testing:
    var m2: PackedModule
    discard loadRodFile(filename, m2, encoder.config)

# ----------------------------------------------------------------------------

type
  PackedDecoder* = object
    m: PackedModule
    thisModule*: int32
    lastFile*: FileIndex # remember the last lookup entry.
    lastLit*: LitId
    filenames*: Table[FileIndex, LitId]
    pendingTypes*: seq[PType]
    pendingSyms*: seq[PSym]
    typeMap*: Table[int32, PType]
    symMap*: Table[int32, PSym]
    sh: Shared
    config*: ConfigRef




when false:
  proc initGenericKey*(s: PSym; types: seq[PType]): GenericKey =
    result.module = s.owner.itemId.module
    result.name = s.name.s
    result.types = mapIt types: hashType(it, {CoType, CoDistinct}).MD5Digest

  proc addGeneric*(m: var Module; c: var PackedEncoder; key: GenericKey; s: PSym) =
    ## add a generic to the module
    if key notin m.generics:
      m.generics[key] = toPackedSym(s, m.ast, c)
      toPackedNode(s.ast, m.ast, c)

  proc moduleToIr*(n: PNode; ir: var PackedTree; module: PSym) =
    ## serialize a module into packed ast
    var c: PackedEncoder
    initEncoder(c, module)
    toPackedNode(n, ir, c)
