discard """
  errormsg: '''ambiguous call; both foobar.async'''
  line: 9
  disabled: "32bit"
"""

import foobar
import asyncdispatch, macros

proc bar() {.async.} =
  echo 42

proc foo() {.async.} =
  await bar()

asyncCheck foo()
runForever()
