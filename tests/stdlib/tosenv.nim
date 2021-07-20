discard """
  matrix: "--threads"
  joinable: false
  targets: "c cpp"
"""
import os

block delEnv:
    const dummyEnvVar = "DUMMY_ENV_VAR" # This env var wouldn't be likely to exist to begin with
    doAssert existsEnv(dummyEnvVar) == false
    putEnv(dummyEnvVar, "1")
    doAssert existsEnv(dummyEnvVar) == true
    delEnv(dummyEnvVar)
    doAssert existsEnv(dummyEnvVar) == false
    delEnv(dummyEnvVar) # deleting an already deleted env var
    doAssert existsEnv(dummyEnvVar) == false

block putEnv:
    # raises OSError on invalid input
    doAssertRaises(OSError, putEnv("DUMMY_ENV_VAR_PUT=DUMMY_VALUE",
            "NEW_DUMMY_VALUE"))
    doAssertRaises(OSError, putEnv("", "NEW_DUMMY_VALUE"))

block:
    doAssert getEnv("DUMMY_ENV_VAR_NONEXISTENT", "") == ""
    doAssert getEnv("DUMMY_ENV_VAR_NONEXISTENT", " ") == " "
    doAssert getEnv("DUMMY_ENV_VAR_NONEXISTENT", "Arrakis") == "Arrakis"

block: # bug 18533
    proc c_getenv(env: cstring): cstring {.importc: "getenv",
            header: "<stdlib.h>".}
  var thr: Thread[void]
    proc threadFunc {.thread.} = putEnv("foo", "fooVal2")

    putEnv("foo", "fooVal1")
    echo getEnv("foo")
    createThread(thr, threadFunc)
    joinThreads(thr)
    doAssert getEnv("foo") == $c_getenv("foo")

    doAssertRaises(OSError): delEnv("foo=bar")
