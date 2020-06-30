discard """
output: '''
hasPendingOperations: false
triggerCount: 100
'''
joinable:false
"""

#[
joinable:false otherwise:
Error: unhandled exception: tpendingcheck.nim(7, 9) `not hasPendingOperations()`  [AssertionDefect]
see tests/async/tpendingcheck.nim
]#

import asyncDispatch

var triggerCount = 0
var evs = newSeq[AsyncEvent]()

for i in 0 ..< 100: # has to be lower than the typical physical fd limit
  var ev = newAsyncEvent()
  evs.add(ev)
  addEvent(ev, proc(fd: AsyncFD): bool {.gcsafe,closure.} = triggerCount += 1; true)

for ev in evs:
  ev.trigger()

drain()
echo "hasPendingOperations: ", hasPendingOperations()
echo "triggerCount: ", triggerCount
