##[
avoid code duplication in CI pipelines.
For now, this is only used for openbsd + freebsd, but there is a lot of other code
duplication that could be removed.

## usage
edit this file as needed and then re-generate via:
```bash
nim r tools/ci_generate.nim
```
]##

import std/[strformat, os]

const doNotEdit = "DO NO EDIT DIRECTLY! auto-generated by `nim r tools/ci_generate.nim`"
proc genCiBsd(header: string, batch: int, num: int): string =
  result = fmt"""
## {doNotEdit}

{header}

sources:
- https://github.com/nim-lang/Nim
environment:
  NIM_TESTAMENT_BATCH: "{batch}_{num}"
  CC: /usr/bin/clang
tasks:
- setup: |
    set -e
    cd Nim
    . ci/funs.sh && nimBuildCsourcesIfNeeded
    echo 'export PATH=$HOME/Nim/bin:$PATH' >> $HOME/.buildenv
- test: |
    set -e
    cd Nim
    . ci/funs.sh && nimInternalBuildKochAndRunCI
triggers:
- action: email
  condition: failure
  to: Andreas Rumpf <rumpf_a@web.de>
"""

proc genBuildExtras(echoRun, koch, nim: string): string =
  result = fmt"""
{echoRun} {nim} c --skipUserCfg --skipParentCfg --hints:off koch
{echoRun} {koch} boot -d:release --skipUserCfg --skipParentCfg --hints:off
{echoRun} {koch} tools --skipUserCfg --skipParentCfg --hints:off
"""

proc genWindowsScript(buildAll: bool): string =
  result = fmt"""
@echo off
rem {doNotEdit}
rem Build development version of the compiler; can be rerun safely
rem bare bones version of ci/funs.sh adapted for windows.

rem Read in some common shared variables (shared with other tools),
rem see https://stackoverflow.com/questions/3068929/how-to-read-file-contents-into-a-variable-in-a-batch-file
for /f "delims== tokens=1,2" %%G in (config/build_config.txt) do set %%G=%%H
SET nim_csources=bin\nim_csources_%nim_csourcesHash%.exe
echo "building from csources: %nim_csources%"

if not exist %nim_csourcesDir% (
  git clone -q --depth 1 %nim_csourcesUrl% %nim_csourcesDir%
)

if not exist %nim_csources% (
  cd %nim_csourcesDir%
  git checkout %nim_csourcesHash%
  echo "%PROCESSOR_ARCHITECTURE%"
  if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    SET ARCH=64
  )
  CALL build.bat
  cd ..
  copy /y bin\nim.exe  %nim_csources%
)
"""

  if buildAll:
    result.add genBuildExtras("", "koch", r"bin\nim.exe")

proc genPosixScript(): string =
  result = fmt"""
#! /bin/sh
# {doNotEdit}

# build development version of the compiler; can be rerun safely.
# arguments can be passed, e.g.:
# CC=gcc ucpu=amd64 uos=darwin

set -u # error on undefined variables
set -e # exit on first error

. ci/funs.sh
nimBuildCsourcesIfNeeded "$@"

{genBuildExtras("echo_run", "./koch", "bin/nim")}
"""

proc main()=
  let dir = ".builds"
  # not too large to be resource friendly, refs bug #17107
  let num = 2
    # if you reduce this, make sure to remove files that shouldn't be generated,
    # or better, do the cleanup logic here e.g.: `rm .builds/openbsd_*`
  let headerFreebsd = """
# see https://man.sr.ht/builds.sr.ht/compatibility.md#freebsd
image: freebsd/latest
packages:
- databases/sqlite3
- devel/boehm-gc-threaded
- devel/pcre
- devel/sdl20
- devel/sfml
- www/node
- devel/gmake
"""

  let headerOpenbsd = """
image: openbsd/latest
packages:
- gmake
- sqlite3
- node
- boehm-gc
- pcre
- sfml
- sdl2
- libffi
"""

  for i in 0..<num:
    writeFile(dir / fmt"openbsd_{i}.yml", genCiBsd(headerOpenbsd, i, num))
  writeFile(dir / "freebsd.yml", genCiBsd(headerFreebsd, 0, 1))
  writeFile("build_all.sh", genPosixScript())
  writeFile("build_all.bat", genWindowsScript(buildAll = true))
  writeFile("ci/build_autogen.bat", genWindowsScript(buildAll = false))

when isMainModule:
  main()
