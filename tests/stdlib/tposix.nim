discard """
outputsub: ""
"""

# Test Posix interface

when not defined(windows):

  import posix, posix_utils

  var
    u: Utsname

  discard uname(u)

  writeLine(stdout, u.sysname)
  writeLine(stdout, u.nodename)
  writeLine(stdout, u.release)
  writeLine(stdout, u.machine)


  block:
    # lib/posix/posix_utils.nim
    let diskInfo = posix_utils.getDiskUsage(".")
    doAssert diskInfo is tuple
    doAssert diskInfo[0] is uint64
    doAssert diskInfo[1] is uint64
    doAssert diskInfo[2] is uint64
    doAssert diskInfo.total > 0.uint64
    doAssert diskInfo.used > 0.uint64
    doAssert diskInfo.free > 0.uint64
