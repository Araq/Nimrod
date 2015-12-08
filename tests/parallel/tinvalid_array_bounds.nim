discard """
  file: "tinvalid_array_bounds.nim"
  errormsg: "can prove: i + 1 > 30"
  line: 22
"""

import threadpool

proc f(a: openArray[int]) =
  for x in a: echo x

proc f(a: int) = echo a

proc main() =
  var a: array[0..30, int]
  parallel:
    spawn f(a[0..15])
    spawn f(a[16..30])
    var i = 0
    while i <= 30:
      spawn f(a[i])
      spawn f(a[i+1])
      inc i
      #inc i  # inc i, 2  would be correct here

main()
