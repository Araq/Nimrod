discard """
  file: "tcan_access_hidden_field.nim"
  output: 33
"""

import mcan_access_hidden_field

var myfoo = createFoo(33, 44)

echo myfoo.geta
