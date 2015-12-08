discard """
  file: "tvarargsexpr.nim"
  output: '''success
true
true'''
"""

#bug #913

import macros

macro thirteen(args: varargs[expr]): expr =
  result = newIntLitNode(13)

doAssert(13==thirteen([1,2])) # works
doAssert(13==thirteen(1,2)) # works

doAssert(13==thirteen(1,[2])) # does not work
doAssert(13==thirteen([1], 2)) # does not work

echo "success"

# bug #2545

import macros
macro test(e: varargs[untyped]): expr = bindSym"true"

echo test(a)
echo test(fake=90, arguments=80, also="false", possible=true)
