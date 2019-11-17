discard """
  output: '''
@[1, 2, 3]
Success
@["a", "b", "c"]
0'''
  cmd: '''nim c --gc:destructors $file'''
"""

import os
import math
import lists
import strutils

proc mkleak() =
  # allocate 1 MB via linked lists
  let numberOfLists = 100
  for i in countUp(1, numberOfLists):
    var leakList = initDoublyLinkedList[string]()
    let numberOfLeaks = 5000
    for j in countUp(1, numberOfLeaks):
      leakList.append(newString(200))

proc mkManyLeaks() =
  for i in 0..0:
    mkleak()
  echo "Success"

iterator foobar(c: string): seq[string] {.closure.} =
  yield @["a", "b", c]

proc tsimpleClosureIterator =
  var myc = "c"
  for it in foobar(myc):
    echo it

type
  LazyList = ref object
    c: proc() {.closure.}

proc tlazyList =
  let dep = @[1, 2, 3]
  var x = LazyList(c: proc () = echo(dep))
  x.c()

type
  Foo = ref object

proc tleakingNewStmt =
  var x: Foo
  for i in 0..10:
    new(x)

iterator infinite(): int {.closure.} =
  var i = 0
  while true:
    yield i
    inc i

iterator take(it: iterator (): int, numToTake: int): int {.closure.} =
  var i = 0
  for x in it():
    if i >= numToTake:
      break
    yield x
    inc i

proc take3 =
  for x in infinite.take(3):
    discard

let startMem = getOccupiedMem()
take3()
tlazyList()

mkManyLeaks()
tsimpleClosureIterator()
tleakingNewStmt()
echo getOccupiedMem() - startMem
