#
#
#            Nim's Runtime Library
#        (c) Copyright 2019 Andreas Rumpf
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

# An ``include`` file which contains common code for
# hash sets and tables.

# type Hash = uint

const
  growthFactor = 2

from bitops import fastLog2

when not defined(nimHasDefault):
  template default[T](t: typedesc[T]): T =
    var v: T
    v

const freeMarker = 0
const deletedMarker = -1

# hcode for real keys cannot be zero.  hcode==0 signifies an empty slot.  These
# two procs retain clarity of that encoding without the space cost of an enum.
proc isFilledAndValid(hcode: Hash): bool {.inline.} =
  result = hcode != 0 and hcode != deletedMarker # SPEED: could improve w bit magic

proc isFilled(hcode: Hash): bool {.inline.} =
  result = hcode != 0

type UHash* = uint

proc translateBits(a: UHash, numBitsMask: int): UHash {.inline.} =
  result = (a shr numBitsMask) or (a shl (UHash.sizeof * 8 - numBitsMask))

proc nextTry(h, maxHash: Hash, perturb: var UHash): Hash {.inline.} =
  # an optimization would be to use `(h + 1) and maxHash` for a few iterations
  # and then switch to the formula below, to get "best of both worlds": good
  # cache locality, except when a collision cluster is detected (ie, large number
  # of iterations).
  const PERTURB_SHIFT = 5 # consider using instead `numBitsMask=fastLog2(t.dataLen)`
  result = cast[Hash]((5*cast[uint](h) + 1 + perturb) and cast[uint](maxHash))
  perturb = perturb shr PERTURB_SHIFT

proc mustRehash(length, counter: int): bool {.inline.} =
  assert(length > counter)
  result = (length * 2 < counter * 3) or (length - counter < 4) # synchronize with `rightSize`

proc mustRehash2[T](t: T): bool {.inline.} =
  let counter2 = t.counter + t.countDeleted
  result = mustRehash(t.dataLen, counter2)

template getPerturb*(t: typed, hc: Hash): UHash =
  let numBitsMask=fastLog2(dataLen(t)) # TODO: cache/store in t if needed
  # this makes a major difference for cases like #13393; it causes the bits
  # that were masked out in 1st position so they'll be masked in instead, and
  # influence the recursion in nextTry earlier rather than later.
  translateBits(cast[uint](hc), numBitsMask)

template rawGetKnownHCImpl() {.dirty.} =
  if t.dataLen == 0:
    return -1
  var h: Hash = hc and maxHash(t) # start with real hash value
  var perturb = t.getPerturb(hc)
  var deletedIndex = -1
  while true:
    if isFilledAndValid(t.data[h].hcode):
      # Compare hc THEN key with boolean short circuit. This makes the common case
      # zero ==key's for missing (e.g.inserts) and exactly one ==key for present.
      # It does slow down succeeding lookups by one extra Hash cmp&and..usually
      # just a few clock cycles, generally worth it for any non-integer-like A.
      # TODO: optimize this: depending on type(key), skip hc comparison
      if t.data[h].hcode == hc and t.data[h].key == key:
        return h
      h = nextTry(h, maxHash(t), perturb)
    elif t.data[h].hcode == deletedMarker:
      if deletedIndex == -1:
        deletedIndex = h
      h = nextTry(h, maxHash(t), perturb)
    else:
      break
  if deletedIndex == -1:
    result = -1 - h # < 0 => MISSING; insert idx = -1 - result
  else:
    # we prefer returning a (in fact the 1st found) deleted index
    result = -1 - deletedIndex

proc rawGetKnownHC[X, A](t: X, key: A, hc: Hash): int {.inline.} =
  rawGetKnownHCImpl()

template genHashImpl(key, hc: typed) =
  hc = hash(key)
  if hc == 0: # This almost never taken branch should be very predictable.
    hc = 314159265 # Value doesn't matter; Any non-zero favorite is fine.
  elif hc == deletedMarker:
    hc = 214159261

template genHash(key: typed): Hash =
  var res: Hash
  genHashImpl(key, res)
  res

template rawGetImpl() {.dirty.} =
  genHashImpl(key, hc)
  rawGetKnownHCImpl()

proc rawGet[X, A](t: X, key: A, hc: var Hash): int {.inline.} =
  rawGetImpl()
