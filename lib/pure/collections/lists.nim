#
#
#            Nim's Runtime Library
#        (c) Copyright 2012 Andreas Rumpf
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

## Implementation of:
## * `singly linked lists <#SinglyLinkedList>`_
## * `doubly linked lists <#DoublyLinkedList>`_
## * `singly linked rings <#SinglyLinkedRing>`_ (circular lists)
## * `doubly linked rings <#DoublyLinkedRing>`_ (circular lists)
##
## # Basic Usage
## Because it makes no sense to do otherwise, the `next` and `prev` pointers
## are not hidden from you and can be manipulated directly for efficiency.
##
## ## Lists
runnableExamples:
  var l = initDoublyLinkedList[int]()
  let
    a = newDoublyLinkedNode[int](3)
    b = newDoublyLinkedNode[int](7)
    c = newDoublyLinkedNode[int](9)

  l.add(a)
  l.add(b)
  l.prepend(c)

  assert a.next == b
  assert a.prev == c
  assert c.next == a
  assert c.next.next == b
  assert c.prev == nil
  assert b.next == nil

## ## Rings
runnableExamples:
  var l = initSinglyLinkedRing[int]()
  let
    a = newSinglyLinkedNode[int](3)
    b = newSinglyLinkedNode[int](7)
    c = newSinglyLinkedNode[int](9)

  l.add(a)
  l.add(b)
  l.prepend(c)

  assert c.next == a
  assert a.next == b
  assert c.next.next == b
  assert b.next == c
  assert c.next.next.next == c

## # See also
## * `deques module <deques.html>`_ for double-ended queues
## * `sharedlist module <sharedlist.html>`_ for shared singly-linked lists

import std/private/since

when not defined(nimHasCursor):
  {.pragma: cursor.}

type
  DoublyLinkedNodeObj*[T] = object
    ## A node of a doubly linked list.
    ##
    ## It consists of a `value` field, and pointers to `next` and `prev`.
    next*: <//>(DoublyLinkedNode[T])
    prev* {.cursor.}: DoublyLinkedNode[T]
    value*: T
  DoublyLinkedNode*[T] = ref DoublyLinkedNodeObj[T]

  SinglyLinkedNodeObj*[T] = object
    ## A node of a singly linked list.
    ##
    ## It consists of a `value` field, and a pointer to `next`.
    next*: <//>(SinglyLinkedNode[T])
    value*: T
  SinglyLinkedNode*[T] = ref SinglyLinkedNodeObj[T]

  SinglyLinkedList*[T] = object
    ## A singly linked list.
    head*: <//>(SinglyLinkedNode[T])
    tail* {.cursor.}: SinglyLinkedNode[T]

  DoublyLinkedList*[T] = object
    ## A doubly linked list.
    head*: <//>(DoublyLinkedNode[T])
    tail* {.cursor.}: DoublyLinkedNode[T]

  SinglyLinkedRing*[T] = object
    ## A singly linked ring.
    head*: <//>(SinglyLinkedNode[T])
    tail* {.cursor.}: SinglyLinkedNode[T]

  DoublyLinkedRing*[T] = object
    ## A doubly linked ring.
    head*: DoublyLinkedNode[T]

  SomeLinkedList*[T] = SinglyLinkedList[T] | DoublyLinkedList[T]

  SomeLinkedRing*[T] = SinglyLinkedRing[T] | DoublyLinkedRing[T]

  SomeLinkedCollection*[T] = SomeLinkedList[T] | SomeLinkedRing[T]

  SomeLinkedNode*[T] = SinglyLinkedNode[T] | DoublyLinkedNode[T]

func initSinglyLinkedList*[T](): SinglyLinkedList[T] =
  ## Creates a new singly linked list that is empty.
  ##
  ## Singly linked lists are initialized by default, so it is not necessary to
  ## call this function explicitly.
  runnableExamples:
    let a = initSinglyLinkedList[int]()

  discard

func initDoublyLinkedList*[T](): DoublyLinkedList[T] =
  ## Creates a new doubly linked list that is empty.
  ##
  ## Doubly linked lists are initialized by default, so it is not necessary to
  ## call this function explicitly.
  runnableExamples:
    let a = initDoublyLinkedList[int]()

  discard

func initSinglyLinkedRing*[T](): SinglyLinkedRing[T] =
  ## Creates a new singly linked ring that is empty.
  ##
  ## Singly linked rings are initialized by default, so it is not necessary to
  ## call this function explicitly.
  runnableExamples:
    let a = initSinglyLinkedRing[int]()

  discard

func initDoublyLinkedRing*[T](): DoublyLinkedRing[T] =
  ## Creates a new doubly linked ring that is empty.
  ##
  ## Doubly linked rings are initialized by default, so it is not necessary to
  ## call this function explicitly.
  runnableExamples:
    let a = initDoublyLinkedRing[int]()

  discard

func newDoublyLinkedNode*[T](value: T): <//>(DoublyLinkedNode[T]) =
  ## Creates a new doubly linked node with the given `value`.
  runnableExamples:
    let n = newDoublyLinkedNode[int](5)
    assert n.value == 5

  new(result)
  result.value = value

func newSinglyLinkedNode*[T](value: T): <//>(SinglyLinkedNode[T]) =
  ## Creates a new singly linked node with the given `value`.
  runnableExamples:
    let n = newSinglyLinkedNode[int](5)
    assert n.value == 5

  new(result)
  result.value = value

func toSinglyLinkedList*[T](elems: openArray[T]): SinglyLinkedList[T] {.since: (1, 5, 1).} =
  ## Creates a new `SinglyLinkedList` from the members of `elems`.
  runnableExamples:
    from std/sequtils import toSeq
    let a = [1, 2, 3, 4, 5].toSinglyLinkedList
    assert a.toSeq == [1, 2, 3, 4, 5]

  result = initSinglyLinkedList[T]()
  for elem in elems.items:
    result.add(elem)

func toDoublyLinkedList*[T](elems: openArray[T]): DoublyLinkedList[T] {.since: (1, 5, 1).} =
  ## Creates a new `DoublyLinkedList` from the members of `elems`.
  runnableExamples:
    from std/sequtils import toSeq
    let a = [1, 2, 3, 4, 5].toDoublyLinkedList
    assert a.toSeq == [1, 2, 3, 4, 5]

  result = initDoublyLinkedList[T]()
  for elem in elems.items:
    result.add(elem)

template itemsListImpl() {.dirty.} =
  var it = list.head
  while it != nil:
    yield it.value
    it = it.next

template itemsRingImpl() {.dirty.} =
  var it = ring.head
  if it != nil:
    while true:
      yield it.value
      it = it.next
      if it == ring.head: break

iterator items*[T](list: SomeLinkedList[T]): T =
  ## Yields every value of `list`.
  ##
  ## **See also:**
  ## * `mitems iterator <#mitems.i,SomeLinkedList[T]>`_
  ## * `nodes iterator <#nodes.i,SomeLinkedList[T]>`_
  runnableExamples:
    from std/sugar import collect
    from std/sequtils import toSeq
    let a = collect(initSinglyLinkedList):
      for i in 1..3: 10 * i
    assert toSeq(items(a)) == toSeq(a)
    assert toSeq(a) == @[10, 20, 30]

  itemsListImpl()

iterator items*[T](ring: SomeLinkedRing[T]): T =
  ## Yields every value of `ring`.
  ##
  ## **See also:**
  ## * `mitems iterator <#mitems.i,SomeLinkedRing[T]>`_
  ## * `nodes iterator <#nodes.i,SomeLinkedRing[T]>`_
  runnableExamples:
    from std/sugar import collect
    from std/sequtils import toSeq
    let a = collect(initSinglyLinkedRing):
      for i in 1..3: 10 * i
    assert toSeq(items(a)) == toSeq(a)
    assert toSeq(a) == @[10, 20, 30]

  itemsRingImpl()

iterator mitems*[T](list: var SomeLinkedList[T]): var T =
  ## Yields every value of `list` so that you can modify it.
  ##
  ## **See also:**
  ## * `items iterator <#items.i,SomeLinkedList[T]>`_
  ## * `nodes iterator <#nodes.i,SomeLinkedList[T]>`_
  runnableExamples:
    var a = initSinglyLinkedList[int]()
    for i in 1..5:
      a.add(10 * i)
    assert $a == "[10, 20, 30, 40, 50]"
    for x in mitems(a):
      x = 5 * x - 1
    assert $a == "[49, 99, 149, 199, 249]"

  itemsListImpl()

iterator mitems*[T](ring: var SomeLinkedRing[T]): var T =
  ## Yields every value of `ring` so that you can modify it.
  ##
  ## **See also:**
  ## * `items iterator <#items.i,SomeLinkedRing[T]>`_
  ## * `nodes iterator <#nodes.i,SomeLinkedRing[T]>`_
  runnableExamples:
    var a = initSinglyLinkedRing[int]()
    for i in 1..5:
      a.add(10 * i)
    assert $a == "[10, 20, 30, 40, 50]"
    for x in mitems(a):
      x = 5 * x - 1
    assert $a == "[49, 99, 149, 199, 249]"

  itemsRingImpl()

iterator nodes*[T](list: SomeLinkedList[T]): SomeLinkedNode[T] =
  ## Iterates over every node of `x`. Removing the current node from the
  ## list during traversal is supported.
  ##
  ## **See also:**
  ## * `items iterator <#items.i,SomeLinkedList[T]>`_
  ## * `mitems iterator <#mitems.i,SomeLinkedList[T]>`_
  runnableExamples:
    var a = initDoublyLinkedList[int]()
    for i in 1..5:
      a.add(10 * i)
    assert $a == "[10, 20, 30, 40, 50]"
    for x in nodes(a):
      if x.value == 30:
        a.remove(x)
      else:
        x.value = 5 * x.value - 1
    assert $a == "[49, 99, 199, 249]"

  var it = list.head
  while it != nil:
    let nxt = it.next
    yield it
    it = nxt

iterator nodes*[T](ring: SomeLinkedRing[T]): SomeLinkedNode[T] =
  ## Iterates over every node of `x`. Removing the current node from the
  ## list during traversal is supported.
  ##
  ## **See also:**
  ## * `items iterator <#items.i,SomeLinkedRing[T]>`_
  ## * `mitems iterator <#mitems.i,SomeLinkedRing[T]>`_
  runnableExamples:
    var a = initDoublyLinkedRing[int]()
    for i in 1..5:
      a.add(10 * i)
    assert $a == "[10, 20, 30, 40, 50]"
    for x in nodes(a):
      if x.value == 30:
        a.remove(x)
      else:
        x.value = 5 * x.value - 1
    assert $a == "[49, 99, 199, 249]"

  var it = ring.head
  if it != nil:
    while true:
      let nxt = it.next
      yield it
      it = nxt
      if it == ring.head: break

func `$`*[T](l: SomeLinkedCollection[T]): string =
  ## Turns a list into its string representation for logging and printing.
  runnableExamples:
    let a = [1, 2, 3, 4].toSinglyLinkedList
    assert $a == "[1, 2, 3, 4]"

  result = "["
  for x in nodes(l):
    if result.len > 1: result.add(", ")
    result.addQuoted(x.value)
  result.add("]")

func find*[T](l: SomeLinkedCollection[T], value: T): SomeLinkedNode[T] =
  ## Searches in the list for a value. Returns `nil` if the value does not
  ## exist.
  ##
  ## **See also:**
  ## * `contains func <#contains,SomeLinkedCollection[T],T>`_
  runnableExamples:
    let a = [9, 8].toSinglyLinkedList
    assert a.find(9).value == 9
    assert a.find(1) == nil

  for x in nodes(l):
    if x.value == value: return x

func contains*[T](l: SomeLinkedCollection[T], value: T): bool {.inline.} =
  ## Searches in the list for a value. Returns `false` if the value does not
  ## exist, `true` otherwise. This allows the usage of the `in` and `notin`
  ## operators.
  ##
  ## **See also:**
  ## * `find func <#find,SomeLinkedCollection[T],T>`_
  runnableExamples:
    let a = [9, 8].toSinglyLinkedList
    assert a.contains(9)
    assert 8 in a
    assert(not a.contains(1))
    assert 2 notin a

  result = find(l, value) != nil

func prepend*[T: SomeLinkedList](a: var T, b: T) {.since: (1, 5, 1).} =
  ## Prepends a shallow copy of `b` to the beginning of `a`.
  ##
  ## **See also:**
  ## * `prependMoved func <#prependMoved,T,T>`_
  ##   for moving the second list instead of copying
  runnableExamples:
    from std/sequtils import toSeq
    var a = [4, 5].toSinglyLinkedList
    let b = [1, 2, 3].toSinglyLinkedList
    a.prepend(b)
    assert a.toSeq == [1, 2, 3, 4, 5]
    assert b.toSeq == [1, 2, 3]
    a.prepend(a)
    assert a.toSeq == [1, 2, 3, 4, 5, 1, 2, 3, 4, 5]

  var tmp = b.copy
  tmp.addMoved(a)
  a = tmp

func prependMoved*[T: SomeLinkedList](a, b: var T) {.since: (1, 5, 1).} =
  ## Moves `b` before the head of `a`. Efficiency: O(1).
  ## Note that `b` becomes empty after the operation unless it has the same address as `a`.
  ## Self-prepending results in a cycle.
  ##
  ## **See also:**
  ## * `prepend func <#prepend,T,T>`_
  ##   for prepending a copy of a list
  runnableExamples:
    import std/[sequtils, enumerate, sugar]
    var
      a = [4, 5].toSinglyLinkedList
      b = [1, 2, 3].toSinglyLinkedList
      c = [0, 1].toSinglyLinkedList
    a.prependMoved(b)
    assert a.toSeq == [1, 2, 3, 4, 5]
    assert b.toSeq == []
    c.prependMoved(c)
    let s = collect:
      for i, ci in enumerate(c):
        if i == 6: break
        ci
    assert s == [0, 1, 0, 1, 0, 1]

  b.addMoved(a)
  when defined(js): # XXX: swap broken in js; bug #16771
    (b, a) = (a, b)
  else: swap a, b

func add*[T](list: var SinglyLinkedList[T], n: SinglyLinkedNode[T]) {.inline.} =
  ## Appends (adds to the end) a node `n` to `list`. Efficiency: O(1).
  ##
  ## **See also:**
  ## * `add func <#add,SinglyLinkedList[T],T>`_ for appending a value
  ## * `prepend func <#prepend,SinglyLinkedList[T],SinglyLinkedNode[T]>`_
  ##   for prepending a node
  ## * `prepend func <#prepend,SinglyLinkedList[T],T>`_ for prepending a value
  runnableExamples:
    var a = initSinglyLinkedList[int]()
    let n = newSinglyLinkedNode[int](9)
    a.add(n)
    assert a.contains(9)

  n.next = nil
  if list.tail != nil:
    assert(list.tail.next == nil)
    list.tail.next = n
  list.tail = n
  if list.head == nil: list.head = n

func add*[T](list: var SinglyLinkedList[T], value: T) {.inline.} =
  ## Appends (adds to the end) a value to `list`. Efficiency: O(1).
  ##
  ## **See also:**
  ## * `add func <#add,SinglyLinkedList[T],T>`_ for appending a value
  ## * `prepend func <#prepend,SinglyLinkedList[T],SinglyLinkedNode[T]>`_
  ##   for prepending a node
  ## * `prepend func <#prepend,SinglyLinkedList[T],T>`_ for prepending a value
  runnableExamples:
    var a = initSinglyLinkedList[int]()
    a.add(9)
    a.add(8)
    assert a.contains(9)

  add(list, newSinglyLinkedNode(value))

func prepend*[T](list: var SinglyLinkedList[T],
                 n: SinglyLinkedNode[T]) {.inline.} =
  ## Prepends (adds to the beginning) a node to `list`. Efficiency: O(1).
  ##
  ## **See also:**
  ## * `add func <#add,SinglyLinkedList[T],SinglyLinkedNode[T]>`_
  ##   for appending a node
  ## * `add func <#add,SinglyLinkedList[T],T>`_ for appending a value
  ## * `prepend func <#prepend,SinglyLinkedList[T],T>`_ for prepending a value
  runnableExamples:
    var a = initSinglyLinkedList[int]()
    let n = newSinglyLinkedNode[int](9)
    a.prepend(n)
    assert a.contains(9)

  n.next = list.head
  list.head = n
  if list.tail == nil: list.tail = n

func prepend*[T](list: var SinglyLinkedList[T], value: T) {.inline.} =
  ## Prepends (adds to the beginning) a node to `list`. Efficiency: O(1).
  ##
  ## **See also:**
  ## * `add func <#add,SinglyLinkedList[T],SinglyLinkedNode[T]>`_
  ##   for appending a node
  ## * `add func <#add,SinglyLinkedList[T],T>`_ for appending a value
  ## * `prepend func <#prepend,SinglyLinkedList[T],SinglyLinkedNode[T]>`_
  ##   for prepending a node
  runnableExamples:
    var a = initSinglyLinkedList[int]()
    a.prepend(9)
    a.prepend(8)
    assert a.contains(9)

  prepend(list, newSinglyLinkedNode(value))

func copy*[T](a: SinglyLinkedList[T]): SinglyLinkedList[T] {.since: (1, 5, 1).} =
  ## Creates a shallow copy of `a`.
  runnableExamples:
    from std/sequtils import toSeq
    type Foo = ref object
      x: int
    var
      f = Foo(x: 1)
      a = [f].toSinglyLinkedList
    let b = a.copy
    a.add([f].toSinglyLinkedList)
    assert a.toSeq == [f, f]
    assert b.toSeq == [f] # b isn't modified...
    f.x = 42
    assert a.head.value.x == 42
    assert b.head.value.x == 42 # ... but the elements are not deep copied

    let c = [1, 2, 3].toSinglyLinkedList
    assert $c == $c.copy

  result = initSinglyLinkedList[T]()
  for x in a.items:
    result.add(x)

func addMoved*[T](a, b: var SinglyLinkedList[T]) {.since: (1, 5, 1).} =
  ## Moves `b` to the end of `a`. Efficiency: O(1).
  ## Note that `b` becomes empty after the operation unless it has the same address as `a`.
  ## Self-adding results in a cycle.
  ##
  ## **See also:**
  ## * `add func <#add,T,T>`_ for adding a copy of a list
  runnableExamples:
    import std/[sequtils, enumerate, sugar]
    var
      a = [1, 2, 3].toSinglyLinkedList
      b = [4, 5].toSinglyLinkedList
      c = [0, 1].toSinglyLinkedList
    a.addMoved(b)
    assert a.toSeq == [1, 2, 3, 4, 5]
    assert b.toSeq == []
    c.addMoved(c)
    let s = collect:
      for i, ci in enumerate(c):
        if i == 6: break
        ci
    assert s == [0, 1, 0, 1, 0, 1]

  if a.tail != nil:
    a.tail.next = b.head
  a.tail = b.tail
  if a.head == nil:
    a.head = b.head
  if a.addr != b.addr:
    b.head = nil
    b.tail = nil

func add*[T](list: var DoublyLinkedList[T], n: DoublyLinkedNode[T]) =
  ## Appends (adds to the end) a node `n` to `list`. Efficiency: O(1).
  ##
  ## **See also:**
  ## * `add func <#add,DoublyLinkedList[T],T>`_ for appending a value
  ## * `prepend func <#prepend,DoublyLinkedList[T],DoublyLinkedNode[T]>`_
  ##   for prepending a node
  ## * `prepend func <#prepend,DoublyLinkedList[T],T>`_ for prepending a value
  ## * `remove func <#remove,DoublyLinkedList[T],DoublyLinkedNode[T]>`_
  ##   for removing a node
  runnableExamples:
    var a = initDoublyLinkedList[int]()
    let n = newDoublyLinkedNode[int](9)
    a.add(n)
    assert a.contains(9)

  n.next = nil
  n.prev = list.tail
  if list.tail != nil:
    assert(list.tail.next == nil)
    list.tail.next = n
  list.tail = n
  if list.head == nil: list.head = n

func add*[T](list: var DoublyLinkedList[T], value: T) =
  ## Appends (adds to the end) a value to `list`. Efficiency: O(1).
  ##
  ## **See also:**
  ## * `add func <#add,DoublyLinkedList[T],DoublyLinkedNode[T]>`_
  ##   for appending a node
  ## * `prepend func <#prepend,DoublyLinkedList[T],DoublyLinkedNode[T]>`_
  ##   for prepending a node
  ## * `prepend func <#prepend,DoublyLinkedList[T],T>`_ for prepending a value
  ## * `remove func <#remove,DoublyLinkedList[T],DoublyLinkedNode[T]>`_
  ##   for removing a node
  runnableExamples:
    var a = initDoublyLinkedList[int]()
    a.add(9)
    a.add(8)
    assert a.contains(9)

  add(list, newDoublyLinkedNode(value))

func prepend*[T](list: var DoublyLinkedList[T], n: DoublyLinkedNode[T]) =
  ## Prepends (adds to the beginning) a node `n` to `list`. Efficiency: O(1).
  ##
  ## **See also:**
  ## * `add func <#add,DoublyLinkedList[T],DoublyLinkedNode[T]>`_
  ##   for appending a node
  ## * `add func <#add,DoublyLinkedList[T],T>`_ for appending a value
  ## * `prepend func <#prepend,DoublyLinkedList[T],T>`_ for prepending a value
  ## * `remove func <#remove,DoublyLinkedList[T],DoublyLinkedNode[T]>`_
  ##   for removing a node
  runnableExamples:
    var a = initDoublyLinkedList[int]()
    let n = newDoublyLinkedNode[int](9)
    a.prepend(n)
    assert a.contains(9)

  n.prev = nil
  n.next = list.head
  if list.head != nil:
    assert(list.head.prev == nil)
    list.head.prev = n
  list.head = n
  if list.tail == nil: list.tail = n

func prepend*[T](list: var DoublyLinkedList[T], value: T) =
  ## Prepends (adds to the beginning) a value to `list`. Efficiency: O(1).
  ##
  ## **See also:**
  ## * `add func <#add,DoublyLinkedList[T],DoublyLinkedNode[T]>`_
  ##   for appending a node
  ## * `add func <#add,DoublyLinkedList[T],T>`_ for appending a value
  ## * `prepend func <#prepend,DoublyLinkedList[T],DoublyLinkedNode[T]>`_
  ##   for prepending a node
  ## * `remove func <#remove,DoublyLinkedList[T],DoublyLinkedNode[T]>`_
  ##   for removing a node
  runnableExamples:
    var a = initDoublyLinkedList[int]()
    a.prepend(9)
    a.prepend(8)
    assert a.contains(9)

  prepend(list, newDoublyLinkedNode(value))

func copy*[T](a: DoublyLinkedList[T]): DoublyLinkedList[T] {.since: (1, 5, 1).} =
  ## Creates a shallow copy of `a`.
  runnableExamples:
    from std/sequtils import toSeq
    type Foo = ref object
      x: int
    var
      f = Foo(x: 1)
      a = [f].toDoublyLinkedList
    let b = a.copy
    a.add([f].toDoublyLinkedList)
    assert a.toSeq == [f, f]
    assert b.toSeq == [f] # b isn't modified...
    f.x = 42
    assert a.head.value.x == 42
    assert b.head.value.x == 42 # ... but the elements are not deep copied

    let c = [1, 2, 3].toDoublyLinkedList
    assert $c == $c.copy

  result = initDoublyLinkedList[T]()
  for x in a.items:
    result.add(x)

func addMoved*[T](a, b: var DoublyLinkedList[T]) {.since: (1, 5, 1).} =
  ## Moves `b` to the end of `a`. Efficiency: O(1).
  ## Note that `b` becomes empty after the operation unless it has the same address as `a`.
  ## Self-adding results in a cycle.
  ##
  ## **See also:**
  ## * `add func <#add,T,T>`_
  ##   for adding a copy of a list
  runnableExamples:
    import std/[sequtils, enumerate, sugar]
    var
      a = [1, 2, 3].toDoublyLinkedList
      b = [4, 5].toDoublyLinkedList
      c = [0, 1].toDoublyLinkedList
    a.addMoved(b)
    assert a.toSeq == [1, 2, 3, 4, 5]
    assert b.toSeq == []
    c.addMoved(c)
    let s = collect:
      for i, ci in enumerate(c):
        if i == 6: break
        ci
    assert s == [0, 1, 0, 1, 0, 1]

  if b.head != nil:
    b.head.prev = a.tail
  if a.tail != nil:
    a.tail.next = b.head
  a.tail = b.tail
  if a.head == nil:
    a.head = b.head
  if a.addr != b.addr:
    b.head = nil
    b.tail = nil

func add*[T: SomeLinkedList](a: var T, b: T) {.since: (1, 5, 1).} =
  ## Appends a shallow copy of `b` to the end of `a`.
  ##
  ## **See also:**
  ## * `addMoved func <#addMoved,SinglyLinkedList[T],SinglyLinkedList[T]>`_
  ## * `addMoved func <#addMoved,DoublyLinkedList[T],DoublyLinkedList[T]>`_
  ##   for moving the second list instead of copying
  runnableExamples:
    from std/sequtils import toSeq
    var a = [1, 2, 3].toSinglyLinkedList
    let b = [4, 5].toSinglyLinkedList
    a.add(b)
    assert a.toSeq == [1, 2, 3, 4, 5]
    assert b.toSeq == [4, 5]
    a.add(a)
    assert a.toSeq == [1, 2, 3, 4, 5, 1, 2, 3, 4, 5]

  var tmp = b.copy
  a.addMoved(tmp)

func remove*[T](list: var SinglyLinkedList[T], n: SinglyLinkedNode[T]): bool {.discardable.} =
  ## Removes a node `n` from `list`.
  ## Returns `true` if `n` was found in `list`.
  ## Efficiency: O(n); the list is traversed until `n` is found.
  ## Attempting to remove an element not contained in the list is a no-op.
  ## When the list is cyclic, the cycle is preserved after removal.
  runnableExamples:
    import std/[sequtils, enumerate, sugar]
    var a = [0, 1, 2].toSinglyLinkedList
    let n = a.head.next
    assert n.value == 1
    assert a.remove(n) == true
    assert a.toSeq == [0, 2]
    assert a.remove(n) == false
    assert a.toSeq == [0, 2]
    a.addMoved(a) # cycle: [0, 2, 0, 2, ...]
    a.remove(a.head)
    let s = collect:
      for i, ai in enumerate(a):
        if i == 4: break
        ai
    assert s == [2, 2, 2, 2]

  if n == list.head:
    list.head = n.next
    if list.tail.next == n:
      list.tail.next = list.head # restore cycle
  else:
    var prev = list.head
    while prev.next != n and prev.next != nil:
      prev = prev.next
    if prev.next == nil:
      return false
    prev.next = n.next
  true

func remove*[T](list: var DoublyLinkedList[T], n: DoublyLinkedNode[T]) =
  ## Removes a node `n` from `list`. Efficiency: O(1).
  ## This function assumes, for the sake of efficiency, that `n` is contained in `list`,
  ## otherwise the effects are undefined.
  ## When the list is cyclic, the cycle is preserved after removal.
  runnableExamples:
    import std/[sequtils, enumerate, sugar]
    var a = [0, 1, 2].toSinglyLinkedList
    let n = a.head.next
    assert n.value == 1
    a.remove(n)
    assert a.toSeq == [0, 2]
    a.remove(n)
    assert a.toSeq == [0, 2]
    a.addMoved(a) # cycle: [0, 2, 0, 2, ...]
    a.remove(a.head)
    let s = collect:
      for i, ai in enumerate(a):
        if i == 4: break
        ai
    assert s == [2, 2, 2, 2]

  if n == list.tail: list.tail = n.prev
  if n == list.head: list.head = n.next
  if n.next != nil: n.next.prev = n.prev
  if n.prev != nil: n.prev.next = n.next



func add*[T](ring: var SinglyLinkedRing[T], n: SinglyLinkedNode[T]) =
  ## Appends (adds to the end) a node `n` to `ring`. Efficiency: O(1).
  ##
  ## **See also:**
  ## * `add func <#add,SinglyLinkedRing[T],T>`_ for appending a value
  ## * `prepend func <#prepend,SinglyLinkedRing[T],SinglyLinkedNode[T]>`_
  ##   for prepending a node
  ## * `prepend func <#prepend,SinglyLinkedRing[T],T>`_ for prepending a value
  runnableExamples:
    var a = initSinglyLinkedRing[int]()
    let n = newSinglyLinkedNode[int](9)
    a.add(n)
    assert a.contains(9)

  if ring.head != nil:
    n.next = ring.head
    assert(ring.tail != nil)
    ring.tail.next = n
  else:
    n.next = n
    ring.head = n
  ring.tail = n

func add*[T](ring: var SinglyLinkedRing[T], value: T) =
  ## Appends (adds to the end) a value to `ring`. Efficiency: O(1).
  ##
  ## **See also:**
  ## * `add func <#add,SinglyLinkedRing[T],SinglyLinkedNode[T]>`_
  ##   for appending a node
  ## * `prepend func <#prepend,SinglyLinkedRing[T],SinglyLinkedNode[T]>`_
  ##   for prepending a node
  ## * `prepend func <#prepend,SinglyLinkedRing[T],T>`_ for prepending a value
  runnableExamples:
    var a = initSinglyLinkedRing[int]()
    a.add(9)
    a.add(8)
    assert a.contains(9)

  add(ring, newSinglyLinkedNode(value))

func prepend*[T](ring: var SinglyLinkedRing[T], n: SinglyLinkedNode[T]) =
  ## Prepends (adds to the beginning) a node `n` to `ring`. Efficiency: O(1).
  ##
  ## **See also:**
  ## * `add func <#add,SinglyLinkedRing[T],SinglyLinkedNode[T]>`_
  ##   for appending a node
  ## * `add func <#add,SinglyLinkedRing[T],T>`_ for appending a value
  ## * `prepend func <#prepend,SinglyLinkedRing[T],T>`_ for prepending a value
  runnableExamples:
    var a = initSinglyLinkedRing[int]()
    let n = newSinglyLinkedNode[int](9)
    a.prepend(n)
    assert a.contains(9)

  if ring.head != nil:
    n.next = ring.head
    assert(ring.tail != nil)
    ring.tail.next = n
  else:
    n.next = n
    ring.tail = n
  ring.head = n

func prepend*[T](ring: var SinglyLinkedRing[T], value: T) =
  ## Prepends (adds to the beginning) a value to `ring`. Efficiency: O(1).
  ##
  ## **See also:**
  ## * `add func <#add,SinglyLinkedRing[T],SinglyLinkedNode[T]>`_
  ##   for appending a node
  ## * `add func <#add,SinglyLinkedRing[T],T>`_ for appending a value
  ## * `prepend func <#prepend,SinglyLinkedRing[T],SinglyLinkedNode[T]>`_
  ##   for prepending a node
  runnableExamples:
    var a = initSinglyLinkedRing[int]()
    a.prepend(9)
    a.prepend(8)
    assert a.contains(9)

  prepend(ring, newSinglyLinkedNode(value))



func add*[T](ring: var DoublyLinkedRing[T], n: DoublyLinkedNode[T]) =
  ## Appends (adds to the end) a node `n` to `ring`. Efficiency: O(1).
  ##
  ## **See also:**
  ## * `add func <#add,DoublyLinkedRing[T],T>`_ for appending a value
  ## * `prepend func <#prepend,DoublyLinkedRing[T],DoublyLinkedNode[T]>`_
  ##   for prepending a node
  ## * `prepend func <#prepend,DoublyLinkedRing[T],T>`_ for prepending a value
  ## * `remove func <#remove,DoublyLinkedRing[T],DoublyLinkedNode[T]>`_
  ##   for removing a node
  runnableExamples:
    var a = initDoublyLinkedRing[int]()
    let n = newDoublyLinkedNode[int](9)
    a.add(n)
    assert a.contains(9)

  if ring.head != nil:
    n.next = ring.head
    n.prev = ring.head.prev
    ring.head.prev.next = n
    ring.head.prev = n
  else:
    n.prev = n
    n.next = n
    ring.head = n

func add*[T](ring: var DoublyLinkedRing[T], value: T) =
  ## Appends (adds to the end) a value to `ring`. Efficiency: O(1).
  ##
  ## **See also:**
  ## * `add func <#add,DoublyLinkedRing[T],DoublyLinkedNode[T]>`_
  ##   for appending a node
  ## * `prepend func <#prepend,DoublyLinkedRing[T],DoublyLinkedNode[T]>`_
  ##   for prepending a node
  ## * `prepend func <#prepend,DoublyLinkedRing[T],T>`_ for prepending a value
  ## * `remove func <#remove,DoublyLinkedRing[T],DoublyLinkedNode[T]>`_
  ##   for removing a node
  runnableExamples:
    var a = initDoublyLinkedRing[int]()
    a.add(9)
    a.add(8)
    assert a.contains(9)

  add(ring, newDoublyLinkedNode(value))

func prepend*[T](ring: var DoublyLinkedRing[T], n: DoublyLinkedNode[T]) =
  ## Prepends (adds to the beginning) a node `n` to `ring`. Efficiency: O(1).
  ##
  ## **See also:**
  ## * `add func <#add,DoublyLinkedRing[T],DoublyLinkedNode[T]>`_
  ##   for appending a node
  ## * `add func <#add,DoublyLinkedRing[T],T>`_ for appending a value
  ## * `prepend func <#prepend,DoublyLinkedRing[T],T>`_ for prepending a value
  ## * `remove func <#remove,DoublyLinkedRing[T],DoublyLinkedNode[T]>`_
  ##   for removing a node
  runnableExamples:
    var a = initDoublyLinkedRing[int]()
    let n = newDoublyLinkedNode[int](9)
    a.prepend(n)
    assert a.contains(9)

  if ring.head != nil:
    n.next = ring.head
    n.prev = ring.head.prev
    ring.head.prev.next = n
    ring.head.prev = n
  else:
    n.prev = n
    n.next = n
  ring.head = n

func prepend*[T](ring: var DoublyLinkedRing[T], value: T) =
  ## Prepends (adds to the beginning) a value to `ring`. Efficiency: O(1).
  ##
  ## **See also:**
  ## * `add func <#add,DoublyLinkedRing[T],DoublyLinkedNode[T]>`_
  ##   for appending a node
  ## * `add func <#add,DoublyLinkedRing[T],T>`_ for appending a value
  ## * `prepend func <#prepend,DoublyLinkedRing[T],DoublyLinkedNode[T]>`_
  ##   for prepending a node
  ## * `remove func <#remove,DoublyLinkedRing[T],DoublyLinkedNode[T]>`_
  ##   for removing a node
  runnableExamples:
    var a = initDoublyLinkedRing[int]()
    a.prepend(9)
    a.prepend(8)
    assert a.contains(9)

  prepend(ring, newDoublyLinkedNode(value))

func remove*[T](ring: var DoublyLinkedRing[T], n: DoublyLinkedNode[T]) =
  ## Removes `n` from `ring`. Efficiency: O(1).
  ## This function assumes, for the sake of efficiency, that `n` is contained in `ring`,
  ## otherwise the effects are undefined.
  runnableExamples:
    var a = initDoublyLinkedRing[int]()
    let n = newDoublyLinkedNode[int](5)
    a.add(n)
    assert 5 in a
    a.remove(n)
    assert 5 notin a

  n.next.prev = n.prev
  n.prev.next = n.next
  if n == ring.head:
    let p = ring.head.prev
    if p == ring.head:
      # only one element left:
      ring.head = nil
    else:
      ring.head = p

func append*[T](a: var (SinglyLinkedList[T] | SinglyLinkedRing[T]),
                b: SinglyLinkedList[T] | SinglyLinkedNode[T] | T) =
  ## Alias for `a.add(b)`.
  ##
  ## **See also:**
  ## * `add func <#add,SinglyLinkedList[T],SinglyLinkedNode[T]>`_
  ## * `add func <#add,SinglyLinkedList[T],T>`_
  ## * `add func <#add,T,T>`_
  a.add(b)

func append*[T](a: var (DoublyLinkedList[T] | DoublyLinkedRing[T]),
                b: DoublyLinkedList[T] | DoublyLinkedNode[T] | T) =
  ## Alias for `a.add(b)`.
  ##
  ## **See also:**
  ## * `add func <#add,DoublyLinkedList[T],DoublyLinkedNode[T]>`_
  ## * `add func <#add,DoublyLinkedList[T],T>`_
  ## * `add func <#add,T,T>`_
  a.add(b)

func appendMoved*[T: SomeLinkedList](a, b: var T) {.since: (1, 5, 1).} =
  ## Alias for `a.addMoved(b)`.
  ##
  ## **See also:**
  ## * `addMoved func <#addMoved,SinglyLinkedList[T],SinglyLinkedList[T]>`_
  ## * `addMoved func <#addMoved,DoublyLinkedList[T],DoublyLinkedList[T]>`_
  a.addMoved(b)

