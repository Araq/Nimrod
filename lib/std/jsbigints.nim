## Arbitrary precision integers.
## * https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/BigInt
when not defined(js):
  {.fatal: "Module jsbigints is designed to be used with the JavaScript backend.".}

type JsBigIntImpl {.importc: "bigint".} = int # https://github.com/nim-lang/Nim/pull/16606
type JsBigInt* = distinct JsBigIntImpl        ## Arbitrary precision integer for JavaScript target.

func big*(integer: SomeInteger): JsBigInt {.importjs: "BigInt(#)".} =
  ## Constructor for `JsBigInt`.
  runnableExamples:
    doAssert big(1234567890) == big"1234567890"

func big*(integer: cstring): JsBigInt {.importjs: "BigInt(#)".} =
  ## Constructor for `JsBigInt`.
  runnableExamples:
    doAssert big"-1" == big"1" - big"2"

func toCstring*(this: JsBigInt; radix: 2..36): cstring {.importjs: "#.toString(#)".} =
  ## Converts from `JsBigInt` to `cstring` representation.
  ## * `radix` Base to use for representing numeric values.
  ## https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/BigInt/toString
  runnableExamples:
    doAssert big"2147483647".toCstring(2) == "1111111111111111111111111111111".cstring

func toCstring*(this: JsBigInt): cstring {.importjs: "#.toString()".}
  ## Converts from `JsBigInt` to `cstring` representation.
  ## https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/BigInt/toString

func `$`*(this: JsBigInt): string =
  ## Returns a `string` representation of `JsBigInt`.
  runnableExamples: doAssert $big"1024" == "1024n"
  $toCstring(this) & 'n'

func wrapToInt*(this: JsBigInt; bits: Natural): JsBigInt {.importjs:
  "(() => { const i = #, b = #; return BigInt.asIntN(b, i) })()".} =
  ## Wraps `this` to a signed `JsBigInt` of `bits` bits in `-2 ^ (bits - 1)` .. `2 ^ (bits - 1) - 1`.
  ## https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/BigInt/asIntN
  runnableExamples:
    doAssert (big("3") + big("2") ** big("66")).wrapToInt(13) == big("3")

func wrapToUint*(this: JsBigInt; bits: Natural): JsBigInt {.importjs:
  "(() => { const i = #, b = #; return BigInt.asUintN(b, i) })()".} =
  ## Wraps `this` to an unsigned `JsBigInt` of `bits` bits in 0 ..  `2 ^ bits - 1`.
  ## https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/BigInt/asUintN
  runnableExamples:
    doAssert (big("3") + big("2") ** big("66")).wrapToUint(66) == big("3")

func toNumber*(this: JsBigInt): BiggestInt {.importjs: "Number(#)".} =
  ## Does not do any bounds check and may or may not return an inexact representation.
  runnableExamples:
    doAssert toNumber(big"2147483647") == 2147483647.BiggestInt

func `+`*(x, y: JsBigInt): JsBigInt {.importjs: "(# $1 #)".} =
  runnableExamples:
    doAssert (big"9" + big"1") == big"10"

func `-`*(x, y: JsBigInt): JsBigInt {.importjs: "(# $1 #)".} =
  runnableExamples:
    doAssert (big"9" - big"1") == big"8"

func `*`*(x, y: JsBigInt): JsBigInt {.importjs: "(# $1 #)".} =
  runnableExamples:
    doAssert (big"42" * big"9") == big"378"

func `div`*(x, y: JsBigInt): JsBigInt {.importjs: "(# / #)".} =
  ## Same as `div` but for `JsBigInt`(uses JavaScript `BigInt() / BigInt()`).
  runnableExamples:
    doAssert big"13" div big"3" == big"4"
    doAssert big"-13" div big"3" == big"-4"
    doAssert big"13" div big"-3" == big"-4"
    doAssert big"-13" div big"-3" == big"4"

func `mod`*(x, y: JsBigInt): JsBigInt {.importjs: "(# % #)".} =
  ## Same as `mod` but for `JsBigInt` (uses JavaScript `BigInt() % BigInt()`).
  runnableExamples:
    doAssert big"13" mod big"3" == big"1"
    doAssert big"-13" mod big"3" == big"-1"
    doAssert big"13" mod big"-3" == big"1"
    doAssert big"-13" mod big"-3" == big"-1"

func `<`*(x, y: JsBigInt): bool {.importjs: "(# $1 #)".} =
  runnableExamples:
    doAssert big"2" < big"9"

func `<=`*(x, y: JsBigInt): bool {.importjs: "(# $1 #)".} =
  runnableExamples:
    doAssert big"1" <= big"5"

func `==`*(x, y: JsBigInt): bool {.importjs: "(# === #)".} =
  runnableExamples:
    doAssert big"42" == big"42"

func `**`*(x, y: JsBigInt): JsBigInt {.importjs: "((#) $1 #)".} =
  runnableExamples:
    doAssert (big"9" ** big"5") == big"59049"

func `xor`*(x, y: JsBigInt): JsBigInt {.importjs: "(# ^ #)".} =
  runnableExamples:
    doAssert (big"555" xor big"2") == big"553"

func `shl`*(a, b: JsBigInt): JsBigInt {.importjs: "(# << #)".} =
  runnableExamples:
    doAssert (big"999" shl big"2") == big"3996"

func `shr`*(a, b: JsBigInt): JsBigInt {.importjs: "(# >> #)".} =
  runnableExamples:
    doAssert (big"999" shr big"2") == big"249"

func `-`*(this: JsBigInt): JsBigInt {.importjs: "($1#)".} =
  runnableExamples:
    doAssert -(big"10101010101") == big"-10101010101"

func inc*(this: var JsBigInt) {.importjs: "(++[#][0][0])".} =
  runnableExamples:
    var big1: JsBigInt = big"1"
    inc big1
    doAssert big1 == big"2"

func dec*(this: var JsBigInt) {.importjs: "(--[#][0][0])".} =
  runnableExamples:
    var big1: JsBigInt = big"2"
    dec big1
    doAssert big1 == big"1"

func inc*(this: var JsBigInt; amount: JsBigInt) {.importjs: "([#][0][0] += #)".} =
  runnableExamples:
    var big1: JsBigInt = big"1"
    inc big1, big"2"
    doAssert big1 == big"3"

func dec*(this: var JsBigInt; amount: JsBigInt) {.importjs: "([#][0][0] -= #)".} =
  runnableExamples:
    var big1: JsBigInt = big"1"
    dec big1, big"2"
    doAssert big1 == big"-1"

func `+=`*(x: var JsBigInt; y: JsBigInt) {.importjs: "([#][0][0] $1 #)".} =
  runnableExamples:
    var big1: JsBigInt = big"1"
    big1 += big"2"
    doAssert big1 == big"3"

func `-=`*(x: var JsBigInt; y: JsBigInt) {.importjs: "([#][0][0] $1 #)".} =
  runnableExamples:
    var big1: JsBigInt = big"1"
    big1 -= big"2"
    doAssert big1 == big"-1"

func `*=`*(x: var JsBigInt; y: JsBigInt) {.importjs: "([#][0][0] $1 #)".} =
  runnableExamples:
    var big1: JsBigInt = big"2"
    big1 *= big"4"
    doAssert big1 == big"8"

func `/=`*(x: var JsBigInt; y: JsBigInt) {.importjs: "([#][0][0] /= #)".} =
  ## Same as `x = x div y`.
  runnableExamples:
    var big1: JsBigInt = big"11"
    big1 /= big"2"
    doAssert big1 == big"5"

proc `+`*(_: JsBigInt): JsBigInt {.error:
  "See https://github.com/tc39/proposal-bigint/blob/master/ADVANCED.md#dont-break-asmjs".} # Can not be used by design
  ## **Do NOT use.** https://github.com/tc39/proposal-bigint/blob/master/ADVANCED.md#dont-break-asmjs

proc low*(_: typedesc[JsBigInt]): JsBigInt {.error:
  "Arbitrary precision integers do not have a known low.".} ## **Do NOT use.**

proc high*(_: typedesc[JsBigInt]): JsBigInt {.error:
  "Arbitrary precision integers do not have a known high.".} ## **Do NOT use.**


runnableExamples:
  let big1: JsBigInt = big"2147483647"
  let big2: JsBigInt = big"666"
  doAssert JsBigInt isnot int
  doAssert big1 != big2
  doAssert big1 > big2
  doAssert big1 >= big2
  doAssert big2 < big1
  doAssert big2 <= big1
  doAssert not(big1 == big2)
  let z = JsBigInt.default
  doAssert $z == "0n"
  block:
    var a: seq[JsBigInt]
    a.setLen 2
    doAssert a == @[big"0", big"0"]
    doAssert a[^1] == big"0"
    var b: JsBigInt
    doAssert b == big"0"
    doAssert b == JsBigInt.default
