
import nimhcr_1
import nimhcr_2 # a new and different import!

proc makeCounter*(): auto =
  return iterator: int {.closure.} =
    for i in countup(0, 10, 1):
      yield i

let c = makeCounter()
afterCodeReload:
  echo "   0: after - clojure iterator: ", c()
  echo "   0: after - clojure iterator: ", c()

proc getInt*(): int = return g_1 + g_2.len
