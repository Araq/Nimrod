#
#
#           The Nim Compiler
#        (c) Copyright 2017 Andreas Rumpf
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

## This module implements the canonalization for the various caching mechanisms.

import ast, idgen, lineinfos, incremental, modulegraphs, pathutils, cgendata

when not nimIncremental:
  template setupModuleCache*(g: ModuleGraph) = discard
  template storeNode*(g: ModuleGraph; module: PSym; n: PNode): int64 = 0
  template storeSym*(g: ModuleGraph; module: PSym): int64 = 0
  template loadNode*(g: ModuleGraph; module: PSym): PNode = newNode(nkStmtList)

  proc loadModuleSym*(g: ModuleGraph; fileIdx: FileIndex; fullpath: AbsoluteFile): (PSym, int) {.inline.} = (nil, getID())

  template addModuleDep*(g: ModuleGraph; module, fileIdx: FileIndex; isIncludeFile: bool) = discard

  template storeRemaining*(g: ModuleGraph; module: PSym) = discard

  template registerModule*(g: ModuleGraph; module: PSym) = discard

  template snippetAlreadyStored*(g: ModuleGraph;
                                 fn: AbsoluteFile; p: PSym): bool =
    false
  template symbolAlreadyStored*(g: ModuleGraph; p: PSym): bool = false
  template typeAlreadyStored*(g: ModuleGraph; p: PType): bool = false

  iterator loadSnippets*(g: ModuleGraph; modules: BModuleList;
                         p: PSym): Snippet = discard

  template storeSnippet*(g: ModuleGraph; s: var Snippet) = discard

  template loadModule*(g: ModuleGraph; mid: SqlId; snips: var Snippets) =
    discard

  template setMark*(m: BModule) = discard
  template setMark*(m: BModule; node: PSym) = discard

  iterator snippetsSince*(m: BModule): Snippet = discard

else:
  include rodimpl

  # idea for testing all this logic: *Always* load the AST from the DB, whether
  # we already have it in RAM or not!
