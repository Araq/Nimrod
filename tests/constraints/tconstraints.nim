discard """
  file: "tconstraints.nim"
  line: 17
  errormsg: "type mismatch: got (int literal(232))"
"""

proc myGenericProc[T: object|tuple|ptr|ref|distinct](x: T): string =
  result = $x

type
  TMyObj = tuple[x, y: int]

var
  x: TMyObj

doAssert myGenericProc(x) == "(x: 0, y: 0)"
doAssert myGenericProc(232) == "232"
