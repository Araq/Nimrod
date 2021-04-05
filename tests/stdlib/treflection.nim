discard """
  targets: "c cpp js"
"""

import std/reflection
from std/strutils import contains


block: # getOwnerName, getBackendProcName
  proc fn1 =
    doAssert getOwnerName() == "fn1"
    static: doAssert getOwnerName() == "fn1"
    doAssert "fn1" in getBackendProcName()
  fn1()

  proc fn3(a: int, b = 3.4, c: static string = "def") =
    let s1 = getOwnerName()
    let s2 = getOwnerName() # check we can call this twice
    doAssert s1 == s2
    doAssert s1 == "fn3"
    doAssert getOwnerName(withType = true) == """fn3: proc (a: int; b: float64; c: "def")"""
    const x = getOwnerName()
    doAssert x == s1
    let s3 = getBackendProcName()
    doAssert "fn3" in s3
    doAssert s3 != "fn3"
    let s4 = getBackendProcName() # check we can call this twice
    doAssert s4 == s3
  fn3(3)

  var other: string
  proc fn3b(): auto =
    result = getOwnerName(withType = true)
    other = getOwnerName(withType = true)
  doAssert fn3b() == "fn3b: proc (): untyped"
    # note: `untyped` is returned when return type is not yet known at the point
    # where getOwnerName(withType = true) is called
  doAssert other == "fn3b: proc (): string" # now the return type is known since `result` was set

  proc `fn1b aux`(): (string, string) =
    doAssert "fn1b" in getBackendProcName()
    doAssert "aux" in getBackendProcName()
    (getOwnerName(), getOwnerName(withType = true))

  doAssert `fn1b aux`() == ("fn1baux", "fn1baux: proc (): (string, string)")

  proc `fn1c+aux`(): (string, string) =
    doAssert "fn1c" in getBackendProcName()
    doAssert "aux" in getBackendProcName()
    (getOwnerName(), getOwnerName(withType = true))
  doAssert `fn1c+aux`() == ("fn1c+aux", "fn1c+aux: proc (): (string, string)")

  var witness = 0
  iterator fn4(): int =
    doAssert getOwnerName() == "fn4"
    doAssert getOwnerName(withType = true) == "fn4: proc (): int"
    witness.inc
  for a in fn4(): discard
  doAssert witness == 1

  when not defined(js):
    witness = 0
    iterator fn5(): int {.closure.} =
      doAssert getOwnerName() == "fn5"
      doAssert getOwnerName(withType = true) == "fn5: proc (): int"
      doAssert "fn5" in getBackendProcName()
      witness.inc
    for a in fn5(): discard
    doAssert witness == 1

  func fn6 =
    doAssert getOwnerName() == "fn6"
    doAssert getOwnerName(withType = true) == "fn6: proc ()"
    doAssert "fn6" in getBackendProcName()
  fn6()


type Foo = ref object of RootObj

method fn7(self: Foo): int {.base.} =
  doAssert getOwnerName() == "fn7"
  doAssert getOwnerName(withType = true) == "fn7: proc (self: Foo): int"
  doAssert "fn7" in getBackendProcName()
  3

var a = Foo()
doAssert fn7(a) == 3

const moduleName = "treflection"

doAssert getOwnerName() == moduleName
block:
  doAssert getOwnerName() == moduleName
  template fn8(): string =
    let x = getOwnerName()
    x
  doAssert fn8() == moduleName

import std/macros

macro fn8(a: int, b: static int = 0): (string, string) =
  let a1 = getOwnerName()
  let a2 = getOwnerName(withType = true)
  result = quote: (`a1`, `a2`)

doAssert fn8(1) == ("fn8", "fn8: proc (a: int; b: b:type): (string, string)")