## Arbitrary precision integers.
## * https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/BigInt
when not defined(js):
  {.fatal: "Module jsbigints is designed to be used with the JavaScript backend.".}

type JsBigInt* = ref object of JsRoot ## Arbitrary precision integer for JavaScript target.

func newJsBigInt*(integer: SomeInteger): JsBigInt {.importjs: "BigInt(#)".} =
  ## Constructor for `JsBigInt`.
  runnableExamples:
    doAssert newJsBigInt(1234567890) == newJsBigInt"1234567890"

func newJsBigInt*(integer: cstring): JsBigInt {.importjs: "BigInt(#)".} =
  ## Constructor for `JsBigInt`.
  runnableExamples:
    doAssert newJsBigInt"-1" == newJsBigInt"1" - newJsBigInt"2"

func toCstring*(this: JsBigInt; radix: 2..36): cstring {.importjs: "#.toString(#)".} =
  ## Convert from `JsBigInt` to `cstring` representation.
  ## * `radix` Base to use for representing numeric values.
  ## https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/BigInt/toString
  runnableExamples:
    doAssert newJsBigInt"2147483647".toCstring(2) == "1111111111111111111111111111111".cstring

func toCstring*(this: JsBigInt): cstring {.importjs: "#.toString()".}
  ## Convert from `JsBigInt` to `cstring` representation.
  ## https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/BigInt/toString

func `$`*(this: JsBigInt): string =
  ## Returns a `string` representation of `JsBigInt`.
  runnableExamples: doAssert $newJsBigInt"1024" == "1024"
  $toCstring(this)

func wrapToInt*(this: JsBigInt; bits: Natural): JsBigInt {.importjs:
  "(() => { const i = #, b = #; return BigInt.asIntN(b, i) })()".} =
  ## Wrap `a` to a signed `JsBigInt` of `bits` bits, for example between `-2 ^ (bits - 1)` and `2 ^ (bits - 1) - 1`.
  ## https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/BigInt/asIntN
  runnableExamples:
    doAssert wrapToInt(32, newJsBigInt"2147483647") == newJsBigInt"2147483647"

func wrapToUint*(this: JsBigInt; bits: Natural): JsBigInt {.importjs:
  "(() => { const i = #, b = #; return BigInt.asUintN(b, i) })()".} =
  ## https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/BigInt/asUintN
  runnableExamples:
    doAssert wrapToUint(32, newJsBigInt"2147483647") == newJsBigInt"2147483647"

func unsafeToNumber*(this: JsBigInt): int {.importjs: "Number(#)".} =
  ## Does not do any bounds check and may or may not return an inexact representation.
  runnableExamples:
    doAssert unsafeToNumber(newJsBigInt"2147483647") == 2147483647

func `+`*(x, y: JsBigInt): JsBigInt {.importjs: "(# $1 #)".} =
  runnableExamples:
    doAssert (newJsBigInt"9" + newJsBigInt"1") == newJsBigInt"10"

func `-`*(x, y: JsBigInt): JsBigInt {.importjs: "(# $1 #)".} =
  runnableExamples:
    doAssert (newJsBigInt"9" - newJsBigInt"1") == newJsBigInt"8"

func `*`*(x, y: JsBigInt): JsBigInt {.importjs: "(# $1 #)".} =
  runnableExamples:
    doAssert (newJsBigInt"42" * newJsBigInt"9") == newJsBigInt"378"

func `div`*(x, y: JsBigInt): JsBigInt {.importjs: "(# / #)".} =
  ## Same as `div` but for `JsBigInt`(uses JavaScript `BigInt() / BigInt()`).
  runnableExamples:
    doAssert newJsBigInt"13" div newJsBigInt"3" == newJsBigInt"4"
    doAssert newJsBigInt"-13" div newJsBigInt"3" == newJsBigInt"-4"
    doAssert newJsBigInt"13" div newJsBigInt"-3" == newJsBigInt"-4"
    doAssert newJsBigInt"-13" div newJsBigInt"-3" == newJsBigInt"4"

func `mod`*(x, y: JsBigInt): JsBigInt {.importjs: "(# % #)".} =
  ## Same as `mod` but for `JsBigInt` (uses JavaScript `BigInt() % BigInt()`).
  runnableExamples:
    doAssert newJsBigInt"13" mod newJsBigInt"3" == newJsBigInt"1"
    doAssert newJsBigInt"-13" mod newJsBigInt"3" == newJsBigInt"-1"
    doAssert newJsBigInt"13" mod newJsBigInt"-3" == newJsBigInt"1"
    doAssert newJsBigInt"-13" mod newJsBigInt"-3" == newJsBigInt"-1"

func `<`*(x, y: JsBigInt): bool {.importjs: "(# $1 #)".} =
  runnableExamples:
    doAssert newJsBigInt"2" < newJsBigInt"9"

func `<=`*(x, y: JsBigInt): bool {.importjs: "(# $1 #)".} =
  runnableExamples:
    doAssert newJsBigInt"1" <= newJsBigInt"5"

func `==`*(x, y: JsBigInt): bool {.importjs: "(# === #)".} =
  runnableExamples:
    doAssert newJsBigInt"42" == newJsBigInt"42"

func `**`*(x, y: JsBigInt): JsBigInt {.importjs: "((#) $1 #)".} =
  runnableExamples:
    doAssert (newJsBigInt"9" ** newJsBigInt"5") == newJsBigInt"59049"

func `xor`*(x, y: JsBigInt): JsBigInt {.importjs: "(# ^ #)".} =
  runnableExamples:
    doAssert (newJsBigInt"555" xor newJsBigInt"2") == newJsBigInt"553"

func `shl`*(a, b: JsBigInt): JsBigInt {.importjs: "(# << #)".} =
  runnableExamples:
    doAssert (newJsBigInt"999" shl newJsBigInt"2") == newJsBigInt"3996"

func `shr`*(a, b: JsBigInt): JsBigInt {.importjs: "(# >> #)".} =
  runnableExamples:
    doAssert (newJsBigInt"999" shr newJsBigInt"2") == newJsBigInt"249"

func `-`*(this: JsBigInt): JsBigInt {.importjs: "($1#)".} =
  runnableExamples:
    doAssert -(newJsBigInt"10101010101") == newJsBigInt"-10101010101"

func inc*(this: var JsBigInt) {.importjs: "(++[#][0][0])".} =
  runnableExamples:
    var big1: JsBigInt = newJsBigInt"1"
    inc big1
    doAssert big1 == newJsBigInt"2"

func dec*(this: var JsBigInt) {.importjs: "(--[#][0][0])".} =
  runnableExamples:
    var big1: JsBigInt = newJsBigInt"2"
    dec big1
    doAssert big1 == newJsBigInt"1"

func inc*(this: var JsBigInt; amount: JsBigInt) {.importjs: "([#][0][0] += [#][0][0])".} =
  runnableExamples:
    var big1: JsBigInt = newJsBigInt"1"
    inc big1, newJsBigInt"2"
    doAssert big1 == newJsBigInt"3"

func dec*(this: var JsBigInt; amount: JsBigInt) {.importjs: "([#][0][0] -= [#][0][0])".} =
  runnableExamples:
    var big1: JsBigInt = newJsBigInt"1"
    dec big1, newJsBigInt"2"
    doAssert big1 == newJsBigInt"-1"

func inc*(this: var JsBigInt; amount: Positive) {.importjs: "([#][0][0] += BigInt(#))".} =
  runnableExamples:
    var big1: JsBigInt = newJsBigInt"1"
    inc big1, 2
    doAssert big1 == newJsBigInt"3"

func dec*(this: var JsBigInt; amount: Positive) {.importjs: "([#][0][0] -= BigInt(#))".} =
  runnableExamples:
    var big1: JsBigInt = newJsBigInt"1"
    dec big1, 2
    doAssert big1 == newJsBigInt"-1"

func `+=`*(x: var JsBigInt; y: JsBigInt) {.importjs: "([#][0][0] $1 [#][0][0])".} =
  runnableExamples:
    var big1: JsBigInt = newJsBigInt"1"
    big1 += 2
    doAssert big1 == newJsBigInt"3"

func `-=`*(x: var JsBigInt; y: JsBigInt) {.importjs: "([#][0][0] $1 [#][0][0])".} =
  runnableExamples:
    var big1: JsBigInt = newJsBigInt"1"
    big1 -= 2
    doAssert big1 == newJsBigInt"-1"

func `*=`*(x: var JsBigInt; y: JsBigInt) {.importjs: "([#][0][0] $1 [#][0][0])".} =
  runnableExamples:
    var big1: JsBigInt = newJsBigInt"2"
    big1 *= 4
    doAssert big1 == newJsBigInt"8"

func `/=`*(x: var JsBigInt; y: JsBigInt) {.importjs: "([#][0][0] /= [#][0][0])".} =
  ## Same as `x = x div y`.
  runnableExamples:
    var big1: JsBigInt = newJsBigInt"11"
    big1 /= 2
    doAssert big1 == newJsBigInt"5"

proc `+`*(_: JsBigInt): JsBigInt {.error:
  "See https://github.com/tc39/proposal-bigint/blob/master/ADVANCED.md#dont-break-asmjs".} # Can not be used by design
  ## **Do NOT use.** https://github.com/tc39/proposal-bigint/blob/master/ADVANCED.md#dont-break-asmjs

proc low*(_: typedesc[JsBigInt]): JsBigInt {.error:
  "Arbitrary precision integers do not have a known low.".} ## **Do NOT use.**

proc high*(_: typedesc[JsBigInt]): JsBigInt {.error:
  "Arbitrary precision integers do not have a known high.".} ## **Do NOT use.**


runnableExamples:
  let big1: JsBigInt = newJsBigInt"2147483647"
  let big2: JsBigInt = newJsBigInt"666"
  doAssert big1 != big2
  doAssert big1 > big2
  doAssert big1 >= big2
  doAssert big2 < big1
  doAssert big2 <= big1
  doAssert not(big1 == big2)