discard """
  file: "twrong_string_asgn.nim"
  output: "adf"
"""

import asyncdispatch
const
  test = ["adf"]

proc foo() {.async.} =
  for i in test:
    echo(i)

var finished = false
let x = foo()
x.callback =
  proc () =
    finished = true

while not finished: discard
