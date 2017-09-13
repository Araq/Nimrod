discard """
  output: "Got: 'nnkCall' hi"
"""

import
  macros, strutils

macro outterMacro*(n, blck: untyped): untyped =
  let n = callsite()
  var j : string = "hi"
  proc innerProc(i: int): string =
    echo "Using arg ! " & n.repr
    result = "Got: '" & $n.kind & "' " & $j
  var callNode = n[0]
  expectKind(n, TNimrodNodeKind.nnkCall)
  if n.len != 3 or n[1].kind != TNimrodNodeKind.nnkIdent:
    error("Macro " & callNode.repr &
      " requires the ident passed as parameter (eg: " & callNode.repr &
      "(the_name_you_want)): statements.")
  result = newNimNode(TNimrodNodeKind.nnkStmtList)
  var ass : NimNode = newNimNode(nnkAsgn)
  ass.add(newIdentNode(n[1].ident))
  ass.add(newStrLitNode(innerProc(4)))
  result.add(ass)

var str: string
outterMacro(str):
  "hellow"

echo str

macro mymacro(arg1,arg2,arg3: untyped): untyped =
  # this needs to compile, but how can I test that it actually does the right thing?
  hint("somehint")
  warning("somewarning")
  hint("myhint", arg1)
  warning("mywarning", arg2)
  error("myerror", arg3)

# mymacro(ident1, ident2, ident3)
