##[
Represents absolute paths, but using a symbolic variables (eg $nimr) which can be
resolved at runtime; this avoids hardcoding at compile time absolute paths so
that the project root can be relocated.

xxx consider some refactoring with $nim/testament/lib/stdtest/specialpaths.nim;
specialpaths is simpler because it doesn't need variables to be relocatable at
runtime (eg for use in testament)

interpolation variables:
  $nimr: such that `$nimr/lib/system.nim` exists (avoids confusion with $nim binary)
         in compiler, it's obtainable via getPrefixDir(); for other tools (eg koch),
        this could be getCurrentDir() or getAppFilename().parentDir.parentDir,
        depending on use case

Unstable API
]##

import std/[os,strutils]

const
  docCss* = "$nimr/doc/nimdoc.css"
  docHackNim* = "$nimr/tools/dochack/dochack.nim"
  docHackJs* = docHackNim.changeFileExt("js")
  docHackJsFname* = docHackJs.lastPathPart
  theindexFname* = "theindex.html"
  nimdocOutCss* = "nimdoc.out.css"
    # `out` to make it easier to use with gitignore in user's repos
  htmldocsDirname* = "htmldocs"

proc interp*(path: string, nimr: string): string =
  result = path % ["nimr", nimr]
  doAssert '$' notin result, $(path, nimr, result) # avoids un-interpolated variables in output

proc getDocHacksJs*(nimr: string, nim = getCurrentCompilerExe(), forceRebuild = false): string =
  ## return absolute path to dochhack.js, rebuilding if it doesn't exist or if
  ## `forceRebuild`.
  let docHackJs2 = docHackJs.interp(nimr = nimr)
  if forceRebuild or not docHackJs2.fileExists:
    let cmd =  "$nim js $file" % ["nim", nim.quoteShell, "file", docHackNim.interp(nimr = nimr).quoteShell]
    echo "getDocHacksJs: cmd: " & cmd
    doAssert execShellCmd(cmd) == 0, $(cmd)
  doAssert docHackJs2.fileExists
  result = docHackJs2
