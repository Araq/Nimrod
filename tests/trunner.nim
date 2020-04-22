discard """
  joinable: false
"""

## tests that don't quite fit the mold and are easier to handle via `execCmdEx`
## A few others could be added to here to simplify code.

import std/[strformat,os,osproc,strutils]

let mode = if existsEnv("NIM_COMPILE_TO_CPP"): "cpp" else: "c"

proc runCmd(file, options = ""): auto =
  const nim = getCurrentCompilerExe()
  const testsDir = currentSourcePath().parentDir
  let fileabs = testsDir / file.unixToNativePath
  doAssert fileabs.existsFile, fileabs
  let cmd = fmt"{nim} {mode} {options} --hints:off {fileabs}"
  result = execCmdEx(cmd)
  when false: # uncomment if you need to debug
    echo result[0]
    echo result[1]

proc testCodegenStaticAssert() =
  let (output, exitCode) = runCmd("ccgbugs/mstatic_assert.nim")
  doAssert "sizeof(bool) == 2" in output
  doAssert exitCode != 0

proc testBackendWarnings() =
  when defined clang:
    let (output, exitCode) = runCmd("misc/mbackendwarnings.nim", "-f --warning:backendWarning:on --stacktrace:off")
    doAssert r"warning_1" in output, output
    doAssert r"warning_2" in output, output
    doAssert r"no_warning" notin output, output  # sanity check
    doAssert exitCode == 0, output

proc testCTFFI() =
  let (output, exitCode) = runCmd("vm/mevalffi.nim", "--experimental:compiletimeFFI")
  let expected = """
hello world stderr
hi stderr
foo0
foo1:101
foo2:102:103
foo3:102:103:104
foo4:0.03:asdf:103:105
foo5:{s1:foobar s2:foobar age:25 pi:3.14}
"""
  doAssert output == expected, output
  doAssert exitCode == 0

when defined(nimHasLibFFIEnabled):
  testCTFFI()
else: # don't run twice the same test
  testCodegenStaticAssert()
  testBackendWarnings()
