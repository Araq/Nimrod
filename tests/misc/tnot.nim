discard """
  file: "system.nim"
  tline: 14
  errormsg: "type mismatch"
"""
# BUG: following compiles, but should not:

proc nodeOfDegree(x: int): bool =
  result = false

proc main =
  for j in 0..2:
    for i in 0..10:
      if not nodeOfDegree(1) >= 0: #ERROR_MSG type mismatch
        echo "Yes"
      else:
        echo "No"

main()
