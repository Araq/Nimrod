discard """
  line: 24
  errormsg: "invalid indentation"
"""

import macros

# finally optional indentation in 'if' expressions :-):
var x = if 4 != 5:
    "yes"
  else:
    "no"

macro mymacro(n: expr): expr = result = n[1][0]

mymacro:
  echo "test"
else:
  echo "else part"
  

if 4 == 3:
  echo "bug"
  else:
  echo "no bug"


