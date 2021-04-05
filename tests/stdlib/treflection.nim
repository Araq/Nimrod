discard """
  targets: "c cpp js"
"""

import std/reflection
from std/strutils import contains


block:
  proc fn1 =
    doAssert getProcname() == "fn1"
    static: doAssert getProcname() == "fn1"
    doAssert "fn1" in getExportcName()
  fn1()

  proc fn3(a: int, b = 3.4, c: static string = "def") =
    let s1 = getProcname()
    let s2 = getProcname() # check we can call this twice
    doAssert s1 == s2
    doAssert s1 == "fn3"
    doAssert getProcname(withType = true) == """fn3: proc (a: int; b: float64; c: "def")"""
    const x = getProcname()
    doAssert x == s1
    let s3 = getExportcName()
    doAssert "fn3" in s3
    doAssert s3 != "fn3"
    let s4 = getExportcName() # check we can call this twice
    doAssert s4 == s3
  fn3(3)

  proc `fn1b aux`(): auto =
    doAssert "fn1b" in getExportcName()
    doAssert "aux" in getExportcName()
    (getProcname(), getProcname(withType = true))

  # xxx bug: `untyped` is returned when return type is auto (it's a bug with `getTypeInst.repr`)
  doAssert `fn1b aux`() == ("fn1baux", "fn1baux: proc (): untyped")

  proc `fn1c+aux`(): auto =
    doAssert "fn1c" in getExportcName()
    doAssert "aux" in getExportcName()
    (getProcname(), getProcname(withType = true))
  doAssert `fn1c+aux`() == ("fn1c+aux", "fn1c+aux: proc (): untyped")

  var witness = 0
  iterator fn4(): int =
    doAssert getProcname() == "fn4"
    doAssert getProcname(withType = true) == "fn4: proc (): int"
    witness.inc
  for a in fn4(): discard
  doAssert witness == 1

  when not defined(js):
    witness = 0
    iterator fn5(): int {.closure.} =
      doAssert getProcname() == "fn5"
      doAssert getProcname(withType = true) == "fn5: proc (): int"
      doAssert "fn5" in getExportcName()
      witness.inc
    for a in fn5(): discard
    doAssert witness == 1

  func fn6 =
    doAssert getProcname() == "fn6"
    doAssert getProcname(withType = true) == "fn6: proc ()"
    doAssert "fn6" in getExportcName()
  fn6()


type Foo = ref object of RootObj

method fn7(self: Foo): int {.base.} =
  doAssert getProcname() == "fn7"
  doAssert getProcname(withType = true) == "fn7: proc (self: Foo): int"
  doAssert "fn7" in getExportcName()
  3

var a = Foo()
doAssert fn7(a) == 3

const moduleName = "treflection"

doAssert getProcname() == moduleName
block:
  doAssert getProcname() == moduleName
  template fn8(): string =
    let x = getProcname()
    x
  doAssert fn8() == moduleName

import std/macros

macro fn8(a: int, b: static int = 0): (string, string) =
  let a1 = getProcname()
  let a2 = getProcname(withType = true)
  result = quote: (`a1`, `a2`)

doAssert fn8(1) == ("fn8", "fn8: proc (a: int; b: b:type): (string, string)")
