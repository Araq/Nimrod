import macros

block: # hasArgOfName
  macro m(u: untyped): untyped =
    for name in ["s","i","j","k","b","xs","ys"]:
      doAssert hasArgOfName(params u,name)
    doAssert not hasArgOfName(params u,"nonexistent")

  proc p(s: string; i,j,k: int; b: bool; xs,ys: seq[int] = @[]) {.m.} = discard

block: # newVarStmt
  macro define(name: string, value: untyped): untyped =
    newVarStmt(name, value)
  
  define("x", 5 + 5)
  doAssert x == 10