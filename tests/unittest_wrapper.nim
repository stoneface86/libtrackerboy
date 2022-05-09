## module provides a wrapper template for using std/unittests
## The wrapper uses a custom OutputFormatter class that only prints
## failures. Thus a successful test run will have no output, allowing us to
## join any test that uses std/unittest

import std/[options, unittest]
export unittest

type
    TestFailure = object
        name: string
        checkpoints: seq[string]
        stackTrace: string

    CustomFormatter* = ref object of OutputFormatter
        failures: seq[TestFailure]
        lastFailureIndex: Option[int]
        lastSuiteName: string

proc printFailure(tf: TestFailure, indent: static bool) =
    when indent:
        stdout.write("  ")
    echo "[FAILED] ", tf.name
    for checkpoint in tf.checkpoints:
        stdout.write(when indent: "    " else: "  ")
        echo checkpoint
    if tf.stackTrace.len > 0:
        echo "---- Stack Trace --------"
        echo tf.stackTrace
        echo "---- End Stack Trace ----"

proc lastFailure(f: CustomFormatter): var TestFailure =
    f.failures[f.lastFailureIndex.get()]

{.warning[LockLevel]:off.}

method suiteStarted*(f: CustomFormatter, suiteName: string) =
    f.lastSuiteName = suiteName

method suiteEnded*(f: CustomFormatter) =
    if f.failures.len > 0:
        echo "[SUITE] ", f.lastSuiteName
        for failure in f.failures:
            printFailure(failure, true)
        f.failures.setLen(0)

method testStarted*(f: CustomFormatter, testName: string) =
    discard

method testEnded*(f: CustomFormatter, testResult: TestResult) =
    if f.lastFailureIndex.isSome():
        f.lastFailure.name = testResult.testName
        if testResult.suiteName.len == 0:
            printFailure(f.lastFailure, false)
            f.failures.setLen(0)
        f.lastFailureIndex = none(int)


method failureOccurred*(f: CustomFormatter, checkpoints: seq[string], stackTrace: string) {.gcsafe.} =
    if f.lastFailureIndex.isNone():
        f.lastFailureIndex = some(f.failures.len)
        f.failures.add(TestFailure(checkpoints: checkpoints, stackTrace: stackTrace))
    else:
        f.lastFailure.checkpoints.add(checkpoints)
        f.lastFailure.stackTrace = stackTrace

{.warning[LockLevel]:on.}

proc newCustomFormatter*(): CustomFormatter =
    CustomFormatter()


template unittests*(body: untyped): untyped =
    ## Uses a custom output formatter to only print failures, allowing us to
    ## join tests that use std/unittest
    let formatter = newCustomFormatter()
    addOutputFormatter(formatter)

    body

    delOutputFormatter(formatter)


when isMainModule:

    unittests:
        test "requires fail":
            require false

        suite "my suite":

            test "multiple fails":
                check false
                checkpoint "a checkpoint"
                check false
            
            test "passes":
                discard

            test "raises exception":
                raise newException(Exception, "an exception")

        test "fails":
            check false
        test "passes":
            discard
