discard """
  action: run
  targets: '''c js'''
"""

import math
let x = -0.0
doAssert classify(x) == fcNegZero