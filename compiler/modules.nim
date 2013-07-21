#
#
#           The Nimrod Compiler
#        (c) Copyright 2013 Andreas Rumpf
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

## implements the module handling

import
  ast, astalgo, magicsys, crc, rodread, msgs, cgendata, sigmatch, options, 
  idents, os, lexer, idgen, passes, syntaxes

type
  TNeedRecompile* = enum Maybe, No, Yes, Probing, Recompiled
  TCrcStatus* = enum crcNotTaken, crcCached, crcHasChanged, crcNotChanged

  TModuleInMemory* = object
    compiledAt*: float
    crc*: TCrc32
    deps*: seq[int32] ## XXX: slurped files are not currently tracked
    needsRecompile*: TNeedRecompile
    crcStatus*: TCrcStatus

var
  gCompiledModules: seq[PSym] = @[]
  gMemCacheData*: seq[TModuleInMemory] = @[]
    ## XXX: we should implement recycling of file IDs
    ## if the user keeps renaming modules, the file IDs will keep growing

proc getModule(fileIdx: int32): PSym =
  if fileIdx >= 0 and fileIdx < gCompiledModules.len:
    result = gCompiledModules[fileIdx]

template compiledAt(x: PSym): expr =
  gMemCacheData[x.position].compiledAt

template crc(x: PSym): expr =
  gMemCacheData[x.position].crc

proc crcChanged(fileIdx: int32): bool =
  InternalAssert fileIdx >= 0 and fileIdx < gMemCacheData.len
  
  template updateStatus =
    gMemCacheData[fileIdx].crcStatus = if result: crcHasChanged
                                       else: crcNotChanged
    # echo "TESTING CRC: ", fileIdx.toFilename, " ", result
  
  case gMemCacheData[fileIdx].crcStatus:
  of crcHasChanged:
    result = true
  of crcNotChanged:
    result = false
  of crcCached:
    let newCrc = crcFromFile(fileIdx.toFilename)
    result = newCrc != gMemCacheData[fileIdx].crc
    gMemCacheData[fileIdx].crc = newCrc
    updateStatus()
  of crcNotTaken:
    gMemCacheData[fileIdx].crc = crcFromFile(fileIdx.toFilename)
    result = true
    updateStatus()

proc doCRC(fileIdx: int32) =
  if gMemCacheData[fileIdx].crcStatus == crcNotTaken:
    # echo "FIRST CRC: ", fileIdx.ToFilename
    gMemCacheData[fileIdx].crc = crcFromFile(fileIdx.toFilename)

proc addDep(x: Psym, dep: int32) =
  growCache gMemCacheData, dep
  gMemCacheData[x.position].deps.safeAdd(dep)

proc resetModule*(fileIdx: int32) =
  # echo "HARD RESETTING ", fileIdx.toFilename
  gMemCacheData[fileIdx].needsRecompile = Yes
  gCompiledModules[fileIdx] = nil
  cgendata.gModules[fileIdx] = nil
  resetSourceMap(fileIdx)

proc resetAllModules* =
  for i in 0..gCompiledModules.high:
    if gCompiledModules[i] != nil:
      resetModule(i.int32)

  # for m in cgenModules(): echo "CGEN MODULE FOUND"

proc checkDepMem(fileIdx: int32): TNeedRecompile =
  template markDirty =
    resetModule(fileIdx)
    return Yes

  if gMemCacheData[fileIdx].needsRecompile != Maybe:
    return gMemCacheData[fileIdx].needsRecompile

  if optForceFullMake in gGlobalOptions or
     crcChanged(fileIdx):
       markDirty
  
  if gMemCacheData[fileIdx].deps != nil:
    gMemCacheData[fileIdx].needsRecompile = Probing
    for dep in gMemCacheData[fileIdx].deps:
      let d = checkDepMem(dep)
      if d in {Yes, Recompiled}:
        # echo fileIdx.toFilename, " depends on ", dep.toFilename, " ", d
        markDirty
  
  gMemCacheData[fileIdx].needsRecompile = No
  return No

proc newModule(fileIdx: int32): PSym =
  # We cannot call ``newSym`` here, because we have to circumvent the ID
  # mechanism, which we do in order to assign each module a persistent ID. 
  new(result)
  result.id = - 1             # for better error checking
  result.kind = skModule
  let filename = fileIdx.toFilename
  result.name = getIdent(splitFile(filename).name)
  if not isNimrodIdentifier(result.name.s):
    rawMessage(errInvalidModuleName, result.name.s)
  
  result.owner = result       # a module belongs to itself
  result.info = newLineInfo(fileIdx, 1, 1)
  result.position = fileIdx
  
  growCache gMemCacheData, fileIdx
  growCache gCompiledModules, fileIdx
  gCompiledModules[result.position] = result
  
  incl(result.flags, sfUsed)
  initStrTable(result.tab)
  StrTableAdd(result.tab, result) # a module knows itself

proc compileModule*(fileIdx: int32, flags: TSymFlags): PSym =
  result = getModule(fileIdx)
  if result == nil:
    growCache gMemCacheData, fileIdx
    gMemCacheData[fileIdx].needsRecompile = Probing
    result = newModule(fileIdx)
    #var rd = handleSymbolFile(result)
    var rd: PRodReader
    result.flags = result.flags + flags
    if gCmd in {cmdCompileToC, cmdCompileToCpp, cmdCheck, cmdIdeTools}:
      rd = handleSymbolFile(result)
      if result.id < 0: 
        InternalError("handleSymbolFile should have set the module\'s ID")
        return
    else:
      result.id = getID()
    processModule(result, nil, rd)
    if optCaasEnabled in gGlobalOptions:
      gMemCacheData[fileIdx].compiledAt = gLastCmdTime
      gMemCacheData[fileIdx].needsRecompile = Recompiled
      doCRC fileIdx
  else:
    if checkDepMem(fileIdx) == Yes:
      result = CompileModule(fileIdx, flags)
    else:
      result = gCompiledModules[fileIdx]

proc importModule*(s: PSym, fileIdx: int32): PSym {.procvar.} =
  # this is called by the semantic checking phase
  result = compileModule(fileIdx, {})
  if optCaasEnabled in gGlobalOptions: addDep(s, fileIdx)
  if sfSystemModule in result.flags:
    LocalError(result.info, errAttemptToRedefine, result.Name.s)

proc includeModule*(s: PSym, fileIdx: int32): PNode {.procvar.} =
  result = syntaxes.parseFile(fileIdx)
  if optCaasEnabled in gGlobalOptions:
    growCache gMemCacheData, fileIdx
    addDep(s, fileIdx)
    doCrc(fileIdx)

proc `==^`(a, b: string): bool =
  try:
    result = sameFile(a, b)
  except EOS:
    result = false

proc compileSystemModule* =
  if magicsys.SystemModule == nil:
    SystemFileIdx = fileInfoIdx(options.libpath/"system.nim")
    discard CompileModule(SystemFileIdx, {sfSystemModule})

proc CompileProject*(projectFile = gProjectMainIdx) =
  let systemFileIdx = fileInfoIdx(options.libpath / "system.nim")
  if projectFile == SystemFileIdx:
    discard CompileModule(projectFile, {sfMainModule, sfSystemModule})
  else:
    compileSystemModule()
    discard CompileModule(projectFile, {sfMainModule})

var stdinModule: PSym
proc makeStdinModule*(): PSym =
  if stdinModule == nil:
    stdinModule = newModule(fileInfoIdx"stdin")
    stdinModule.id = getID()
  result = stdinModule
