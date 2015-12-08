discard """
  file: "tgenericassign.nim"
  output: '''came here'''
"""

type
  TAny* = object {.pure.}
    value*: pointer
    rawType: pointer

proc newAny(value, rawType: pointer): TAny =
  result.value = value
  result.rawType = rawType

var name: cstring = "example"

var ret: seq[tuple[name: string, a: TAny]] = @[]
for i in 0..8000:
  var tup = ($name, newAny(nil, nil))
  doAssert(tup[0] == "example")
  ret.add(tup)
  doAssert(ret[ret.len()-1][0] == "example")

echo "came here"
