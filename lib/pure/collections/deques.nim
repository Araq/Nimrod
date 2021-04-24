#
#
#            Nim's Runtime Library
#        (c) Copyright 2012 Andreas Rumpf
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

## An implementation of a `deque`:idx: (double-ended queue).
## The underlying implementation uses a `seq`.
##
## Deques are implicitly initialised as empty, similar to tables and seqs. But
## trying get an individual value from the deque will result in an `IndexError`
## if compiled with `boundChecks` turned on. Compiling without this option (or
## with `-d:danger` which disables it) may return garbage or crash the program.
##
## As such, a check to see if the deque is empty is needed before any
## access, unless your program logic guarantees it indirectly.
##
runnableExamples:
  var a = [10, 20, 30, 40].toDeque

  doAssertRaises(IndexDefect, echo a[4])

  a.addLast(50)
  assert $a == "[10, 20, 30, 40, 50]"

  assert a.peekFirst == 10
  assert a.peekLast == 50
  assert len(a) == 5

  assert a.popFirst == 10
  assert a.popLast == 50
  assert len(a) == 3

  a.addFirst(11)
  a.addFirst(22)
  a.addFirst(33)
  assert $a == "[33, 22, 11, 20, 30, 40]"

  a.shrink(fromFirst = 1, fromLast = 2)
  assert $a == "[22, 11, 20]"

## See also
## ========
## * `lists module <lists.html>`_ for singly and doubly linked lists and rings
## * `channels module <channels_builtin.html>`_ for inter-thread communication

import std/private/since

import math, hashes

type
  Deque*[T] = object
    ## A double-ended queue backed with a ringed `seq` buffer.
    ##
    ## To initialize an empty deque with a given capacity use
    ## `initDeque proc <#initDeque,int>`_.
    data: seq[T]
    head, tail, count, mask: int

const
  nimDequeDefaultInitialCapacity* {.intdefine.} = 4

template initImpl(result: typed, initialCapacity: int) =
  assert isPowerOfTwo(initialCapacity)
  result.mask = initialCapacity-1
  newSeq(result.data, initialCapacity)

template checkIfInitialized(deq: typed) =
  when declared(nimDequeDefaultInitialCapacity):
    if deq.mask == 0:
      initImpl(deq, nimDequeDefaultInitialCapacity)

proc initDeque*[T](initialCapacity: int = nimDequeDefaultInitialCapacity): Deque[T] =
  ## Create a new empty deque with a given capacity. An implicitly defined
  ## deque will have a capacity of 0 and be grown to fit elements on the first
  ## data insertion.
  ##
  ## Optionally, the initial capacity can be reserved via `initialCapacity`
  ## as a performance optimization. The length of a newly created deque will
  ## still be 0.
  ##
  ## ``initialCapacity`` must be a power of two (default: 4).
  ## If you need to accept runtime values for this you could use the
  ## `nextPowerOfTwo proc<math.html#nextPowerOfTwo,int>`_ from the
  ## `math module<math.html>`_.
  ##
  ## **See also:**
  ## * `toDeque proc <#toDeque,openArray[T]>`_
  result.initImpl(initialCapacity)

proc len*[T](deq: Deque[T]): int {.inline.} =
  ## Return the number of elements in the `deq`.
  result = deq.count

template high*[T](deq: Deque[T]): int =
  deq.len - 1

proc toDeque*[T](x: openArray[T]): Deque[T] {.since: (1, 3).} =
  ## Creates a new deque that contains the elements of `x` (in the same order).
  ##
  ## **See also:**
  ## * `initDeque proc <#initDeque,int>`_
  runnableExamples:
    var x = @[10, 20, 30].toDeque
    assert x.len == 3
    assert x[0] == 10
    x.addFirst 0
    x.addLast 40
    assert $x == "[0, 10, 20, 30, 40]"
  result.head = 0
  result.count = x.len
  result.tail = x.len
  if x.len.isPowerOfTwo:
    result.data.add x
  else:
    let n = x.len.nextPowerOfTwo
    result.data = newSeqOfCap[T](n)
    result.data.add x
    result.data.setLen n
  result.mask = result.data.len - 1

template emptyCheck(deq) =
  # Bounds check for the regular deque access.
  when compileOption("boundChecks"):
    if unlikely(deq.count < 1):
      raise newException(IndexDefect, "Empty deque.")

template xBoundsCheck(deq, i) =
  # Bounds check for the array like accesses.
  when compileOption("boundChecks"): # `-d:danger` or `--checks:off` should disable this.
    if unlikely(i >= deq.count): # x < deq.low is taken care by the Natural parameter
      raise newException(IndexDefect,
                         "Out of bounds: " & $i & " > " & $(deq.count - 1))
    if unlikely(i < 0): # when used with BackwardsIndex
      raise newException(IndexDefect,
                         "Out of bounds: " & $i & " < 0")

proc `[]`*[T](deq: Deque[T], i: Natural): lent T {.inline.} =
  ## Accesses the `i`-th element of `deq`.
  runnableExamples:
    let a = [10, 20, 30, 40, 50].toDeque
    assert a[0] == 10
    assert a[3] == 40
    doAssertRaises(IndexDefect, echo a[8])

  xBoundsCheck(deq, i)
  return deq.data[(deq.head + i) and deq.mask]

proc `[]`*[T](deq: var Deque[T], i: Natural): var T {.inline.} =
  ## Accesses the `i`-th element of `deq` and returns a mutable
  ## reference to it.
  runnableExamples:
    var a = [10, 20, 30, 40, 50].toDeque
    inc(a[0])
    assert a[0] == 11

  xBoundsCheck(deq, i)
  return deq.data[(deq.head + i) and deq.mask]

proc `[]=`*[T](deq: var Deque[T], i: Natural, val: sink T) {.inline.} =
  ## Sets the `i`-th element of `deq` to `val`.
  runnableExamples:
    var a = [10, 20, 30, 40, 50].toDeque
    a[0] = 99
    a[3] = 66
    assert $a == "[99, 20, 30, 66, 50]"

  checkIfInitialized(deq)
  xBoundsCheck(deq, i)
  deq.data[(deq.head + i) and deq.mask] = val

proc `[]`*[T](deq: Deque[T], i: BackwardsIndex): lent T {.inline.} =
  ## Accesses the backwards indexed `i`-th element.
  ##
  ## `deq[^1]` is the last element.
  runnableExamples:
    let a = [10, 20, 30, 40, 50].toDeque
    assert a[^1] == 50
    assert a[^4] == 20
    doAssertRaises(IndexDefect, echo a[^9])

  xBoundsCheck(deq, deq.len - int(i))
  return deq[deq.len - int(i)]

proc `[]`*[T](deq: var Deque[T], i: BackwardsIndex): var T {.inline.} =
  ## Accesses the backwards indexed `i`-th element and returns a mutable
  ## reference to it.
  ##
  ## `deq[^1]` is the last element.
  runnableExamples:
    var a = [10, 20, 30, 40, 50].toDeque
    inc(a[^1])
    assert a[^1] == 51

  xBoundsCheck(deq, deq.len - int(i))
  return deq.data[(deq.head + (deq.len - int(i))) and deq.mask]

proc `[]=`*[T](deq: var Deque[T], i: BackwardsIndex, x: sink T) {.inline.} =
  ## Sets the backwards indexed `i`-th element of `deq` to `x`.
  ##
  ## `deq[^1]` is the last element.
  runnableExamples:
    var a = [10, 20, 30, 40, 50].toDeque
    a[^1] = 99
    a[^3] = 77
    assert $a == "[10, 20, 77, 40, 99]"

  checkIfInitialized(deq)
  xBoundsCheck(deq, deq.len - int(i))
  deq.data[(deq.head + (deq.len - int(i))) and deq.mask] = x

iterator items*[T](deq: Deque[T]): lent T =
  ## Yields every element of `deq`.
  ##
  ## **See also:**
  ## * `mitems iterator <#mitems,Deque[T]>`_
  runnableExamples:
    from std/sequtils import toSeq

    let a = [10, 20, 30, 40, 50].toDeque
    assert toSeq(a.items) == @[10, 20, 30, 40, 50]

  var i = deq.head
  for c in 0 ..< deq.count:
    yield deq.data[i]
    i = (i + 1) and deq.mask

iterator mitems*[T](deq: var Deque[T]): var T =
  ## Yields every element of `deq`, which can be modified.
  ##
  ## **See also:**
  ## * `items iterator <#items,Deque[T]>`_
  runnableExamples:
    var a = [10, 20, 30, 40, 50].toDeque
    assert $a == "[10, 20, 30, 40, 50]"
    for x in mitems(a):
      x = 5 * x - 1
    assert $a == "[49, 99, 149, 199, 249]"

  var i = deq.head
  for c in 0 ..< deq.count:
    yield deq.data[i]
    i = (i + 1) and deq.mask

iterator pairs*[T](deq: Deque[T]): tuple[key: int, val: T] =
  ## Yields every `(position, value)`-pair of `deq`.
  runnableExamples:
    from std/sequtils import toSeq

    let a = [10, 20, 30].toDeque
    assert toSeq(a.pairs) == @[(0, 10), (1, 20), (2, 30)]

  var i = deq.head
  for c in 0 ..< deq.count:
    yield (c, deq.data[i])
    i = (i + 1) and deq.mask

proc contains*[T](deq: Deque[T], item: T): bool {.inline.} =
  ## Returns true if `item` is in `deq` or false if not found.
  ##
  ## Usually used via the `in` operator.
  ## It is the equivalent of `deq.find(item) >= 0`.
  runnableExamples:
    let q = [7, 9].toDeque
    assert 7 in q
    assert q.contains(7)
    assert 8 notin q

  for e in deq:
    if e == item: return true
  return false

proc expandIfNeeded[T](deq: var Deque[T]) =
  checkIfInitialized(deq)
  var cap = deq.mask + 1
  if unlikely(deq.count >= cap):
    var n = newSeq[T](cap * 2)
    var i = 0
    for x in mitems(deq):
      when nimVM: n[i] = x # workaround for VM bug
      else: n[i] = move(x)
      inc i
    deq.data = move(n)
    deq.mask = cap * 2 - 1
    deq.tail = deq.count
    deq.head = 0

proc addFirst*[T](deq: var Deque[T], item: sink T) =
  ## Adds an `item` to the beginning of `deq`.
  ##
  ## **See also:**
  ## * `addLast proc <#addLast,Deque[T],T>`_
  runnableExamples:
    var a: Deque[int]
    for i in 1 .. 5:
      a.addFirst(10 * i)
    assert $a == "[50, 40, 30, 20, 10]"

  expandIfNeeded(deq)
  inc deq.count
  deq.head = (deq.head - 1) and deq.mask
  deq.data[deq.head] = item

proc addLast*[T](deq: var Deque[T], item: sink T) =
  ## Adds an `item` to the end of `deq`.
  ##
  ## **See also:**
  ## * `addFirst proc <#addFirst,Deque[T],T>`_
  runnableExamples:
    var a: Deque[int]
    for i in 1 .. 5:
      a.addLast(10 * i)
    assert $a == "[10, 20, 30, 40, 50]"

  expandIfNeeded(deq)
  inc deq.count
  deq.data[deq.tail] = item
  deq.tail = (deq.tail + 1) and deq.mask

proc peekFirst*[T](deq: Deque[T]): lent T {.inline.} =
  ## Returns the first element of `deq`, but does not remove it from the deque.
  ##
  ## **See also:**
  ## * `peekFirst proc <#peekFirst,Deque[T]_2>`_ which returns a mutable reference
  ## * `peekLast proc <#peekLast,Deque[T]>`_
  runnableExamples:
    let a = [10, 20, 30, 40, 50].toDeque
    assert $a == "[10, 20, 30, 40, 50]"
    assert a.peekFirst == 10
    assert len(a) == 5

  emptyCheck(deq)
  result = deq.data[deq.head]

proc peekLast*[T](deq: Deque[T]): lent T {.inline.} =
  ## Returns the last element of `deq`, but does not remove it from the deque.
  ##
  ## **See also:**
  ## * `peekLast proc <#peekLast,Deque[T]_2>`_ which returns a mutable reference
  ## * `peekFirst proc <#peekFirst,Deque[T]>`_
  runnableExamples:
    let a = [10, 20, 30, 40, 50].toDeque
    assert $a == "[10, 20, 30, 40, 50]"
    assert a.peekLast == 50
    assert len(a) == 5

  emptyCheck(deq)
  result = deq.data[(deq.tail - 1) and deq.mask]

proc peekFirst*[T](deq: var Deque[T]): var T {.inline, since: (1, 3).} =
  ## Returns a mutable reference to the first element of `deq`,
  ## but does not remove it from the deque.
  ##
  ## **See also:**
  ## * `peekFirst proc <#peekFirst,Deque[T]>`_
  ## * `peekLast proc <#peekLast,Deque[T]_2>`_
  runnableExamples:
    var a = [10, 20, 30, 40, 50].toDeque
    a.peekFirst() = 99
    assert $a == "[99, 20, 30, 40, 50]"

  emptyCheck(deq)
  result = deq.data[deq.head]

proc peekLast*[T](deq: var Deque[T]): var T {.inline, since: (1, 3).} =
  ## Returns a mutable reference to the last element of `deq`,
  ## but does not remove it from the deque.
  ##
  ## **See also:**
  ## * `peekFirst proc <#peekFirst,Deque[T]_2>`_
  ## * `peekLast proc <#peekLast,Deque[T]>`_
  runnableExamples:
    var a = [10, 20, 30, 40, 50].toDeque
    a.peekLast() = 99
    assert $a == "[10, 20, 30, 40, 99]"

  emptyCheck(deq)
  result = deq.data[(deq.tail - 1) and deq.mask]

template destroy(x: untyped) =
  reset(x)

proc popFirst*[T](deq: var Deque[T]): T {.inline, discardable.} =
  ## Removes and returns the first element of the `deq`.
  ##
  ## See also:
  ## * `popLast proc <#popLast,Deque[T]>`_
  ## * `shrink proc <#shrink,Deque[T],int,int>`_
  runnableExamples:
    var a = [10, 20, 30, 40, 50].toDeque
    assert $a == "[10, 20, 30, 40, 50]"
    assert a.popFirst == 10
    assert $a == "[20, 30, 40, 50]"

  emptyCheck(deq)
  dec deq.count
  result = move deq.data[deq.head]
  deq.head = (deq.head + 1) and deq.mask

proc popLast*[T](deq: var Deque[T]): T {.inline, discardable.} =
  ## Removes and returns the last element of the `deq`.
  ##
  ## **See also:**
  ## * `popFirst proc <#popFirst,Deque[T]>`_
  ## * `shrink proc <#shrink,Deque[T],int,int>`_
  runnableExamples:
    var a = [10, 20, 30, 40, 50].toDeque
    assert $a == "[10, 20, 30, 40, 50]"
    assert a.popLast == 50
    assert $a == "[10, 20, 30, 40]"

  emptyCheck(deq)
  dec deq.count
  deq.tail = (deq.tail - 1) and deq.mask
  result = move deq.data[deq.tail]

proc clear*[T](deq: var Deque[T]) {.inline.} =
  ## Resets the deque so that it is empty.
  ##
  ## **See also:**
  ## * `shrink proc <#shrink,Deque[T],int,int>`_
  runnableExamples:
    var a = [10, 20, 30, 40, 50].toDeque
    assert $a == "[10, 20, 30, 40, 50]"
    clear(a)
    assert len(a) == 0

  for el in mitems(deq): destroy(el)
  deq.count = 0
  deq.tail = deq.head

proc shrink*[T](deq: var Deque[T], fromFirst = 0, fromLast = 0) =
  ## Removes `fromFirst` elements from the front of the deque and
  ## `fromLast` elements from the back.
  ##
  ## If the supplied number of elements exceeds the total number of elements
  ## in the deque, the deque will be emptied entirely.
  ##
  ## **See also:**
  ## * `clear proc <#clear,Deque[T]>`_
  ## * `popFirst proc <#popFirst,Deque[T]>`_
  ## * `popLast proc <#popLast,Deque[T]>`_
  runnableExamples:
    var a = [10, 20, 30, 40, 50].toDeque
    assert $a == "[10, 20, 30, 40, 50]"
    a.shrink(fromFirst = 2, fromLast = 1)
    assert $a == "[30, 40]"

  if fromFirst + fromLast > deq.count:
    clear(deq)
    return

  for i in 0 ..< fromFirst:
    destroy(deq.data[deq.head])
    deq.head = (deq.head + 1) and deq.mask

  for i in 0 ..< fromLast:
    destroy(deq.data[deq.tail])
    deq.tail = (deq.tail - 1) and deq.mask

  dec deq.count, fromFirst + fromLast

proc `$`*[T](deq: Deque[T]): string =
  ## Turns a deque into its string representation.
  runnableExamples:
    let a = [10, 20, 30].toDeque
    assert $a == "[10, 20, 30]"

  result = "["
  for x in deq:
    if result.len > 1: result.add(", ")
    result.addQuoted(x)
  result.add("]")

proc hash*[A](d: Deque[A]): Hash =
  ## Hashing of Deque.
  runnableExamples:
    var
      x: Deque[int]
      y: Deque[int]

    for i in 1..5:
      x.addLast(i*10)
    for i in -5..10:
      y.addLast(i*10)
    y.shrink(fromFirst = 6, fromLast = 5)
    assert hash(x) == hash(y)
  for h in d:
    result = result !& hash(h)
  result = !$result
