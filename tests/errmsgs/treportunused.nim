discard """
  nimout: '''
treportunused.nim(19, 10) Hint: 'treportunused.s1(a: string)[declared in treportunused.nim(19, 9)]' is declared but not used [XDeclaredButNotUsed]
treportunused.nim(26, 5) Hint: 's8' is declared but not used [XDeclaredButNotUsed]
treportunused.nim(22, 6) Hint: 'treportunused.s4()[declared in treportunused.nim(22, 5)]' is declared but not used [XDeclaredButNotUsed]
treportunused.nim(25, 7) Hint: 's7' is declared but not used [XDeclaredButNotUsed]
treportunused.nim(24, 7) Hint: 's6' is declared but not used [XDeclaredButNotUsed]
treportunused.nim(23, 6) Hint: 'treportunused.s5(a: T)[declared in treportunused.nim(23, 5)]' is declared but not used [XDeclaredButNotUsed]
treportunused.nim(20, 10) Hint: 'treportunused.s2()[declared in treportunused.nim(20, 9)]' is declared but not used [XDeclaredButNotUsed]
treportunused.nim(29, 6) Hint: 's11' is declared but not used [XDeclaredButNotUsed]
treportunused.nim(27, 5) Hint: 's9' is declared but not used [XDeclaredButNotUsed]
treportunused.nim(21, 10) Hint: 's3' is declared but not used [XDeclaredButNotUsed]
treportunused.nim(28, 6) Hint: 's10' is declared but not used [XDeclaredButNotUsed]
'''
"""

# bug #9764

iterator s1(a:string): int = discard
iterator s2(): int = discard
template s3(): untyped = 123
proc s4(): int = 123
proc s5[T](a: T): int = 123
macro s6(a: int): untyped = discard
const s7 = 0
let s8 = 0
var s9: int
type s10 = object
type s11 = type(1.2)
