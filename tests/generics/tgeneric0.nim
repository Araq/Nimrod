discard """
  output: '''
100 0
'''
"""


import tables


block tgeneric0:
  type
    TX = Table[string, int]

  proc foo(models: seq[Table[string, float]]): seq[float] =
    result = @[]
    for model in models.items:
      result.add model["foobar"]

  # bug #686
  type TType[T; A] = array[A, T]

  proc foo[T](p: TType[T, range[0..1]]) =
    echo "foo"
  proc foo[T](p: TType[T, range[0..2]]) =
    echo "bar"

  #bug #1366

  proc reversed(x: auto) =
    for i in countdown(x.low, x.high):
      echo i

  reversed(@[-19, 7, -4, 6])



block tgeneric1:
  type
    TNode[T] = tuple[priority: int, data: T]
    TBinHeap[T] = object
      heap: seq[TNode[T]]
      last: int
    PBinHeap[T] = ref TBinHeap[T]

  proc newBinHeap[T](heap: var PBinHeap[T], size: int) =
    new(heap)
    heap.last = 0
    newSeq(heap.heap, size)
    #newSeq(heap.seq, size)

  proc parent(elem: int): int {.inline.} =
    return (elem-1) div 2

  proc siftUp[T](heap: PBinHeap[T], elem: int) =
    var idx = elem
    while idx != 0:
      var p = parent(idx)
      if heap.heap[idx].priority < heap.heap[p].priority:
        swap(heap.heap[idx], heap.heap[p])
        idx = p
      else:
        break

  proc add[T](heap: PBinHeap[T], priority: int, data: T) =
    var node: TNode[T]
    node.priority = priority
    node.data = data
    heap.heap[heap.last] = node
    siftUp(heap, heap.last)
    inc(heap.last)

  proc print[T](heap: PBinHeap[T]) =
    for i in countup(0, heap.last):
      stdout.write($heap.heap[i].data, " ")

  var heap: PBinHeap[int]

  newBinHeap(heap, 256)
  add(heap, 1, 100)
  print(heap)



block tgeneric2:
  type
    TX = Table[string, int]

  proc foo(models: seq[TX]): seq[int] =
    result = @[]
    for model in models.items:
      result.add model["foobar"]

  type
    Obj = object
      field: Table[string, string]
  var t: Obj
  discard initTable[type(t.field), string]()



block tgeneric4:
  type
    TIDGen[A: Ordinal] = object
      next: A
      free: seq[A]

  proc newIDGen[A]: TIDGen[A] =
      newSeq result.free, 0

  var x = newIDGen[int]()
