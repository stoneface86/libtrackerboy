
import std/os
export parentDir, splitPath

import unittest2
export unittest2

template testclass*(name: string): untyped {.dirty.} =
    ## set the testclass string used by dtest
    const testpath {.used.} = [
        instantiationInfo(fullPaths = true).filename.parentDir.splitPath.tail,
        name
    ]

template dtest*(name: string, body: untyped): untyped =
    ## wrapper for unittests2.test decorating the name
    ## the test's name will be:
    ## <parentDir>.<testclass>.<name>
    ## 
    ## This way we can easily filter tests by parentDir or testclass
    ##  - <parentDir>.* # all tests in parentDir
    ##  - *.<classname>.* # all tests with classname
    ##  - <parentDir>.<classname>.* # all test with both parentDir and classname
    block:
        static: assert declared(testpath), "you must set testclass first!"
        test testpath[0] & "." & testpath[1] & "." & name:
            when declared(dtestSetupIMPLFlag):
                dtestSetupIMPL()
            when declared(dtestTeardownIMPLFlag):
                defer: dtestTeardownIMPL()
            body

template testgroup*(body: untyped): untyped {.dirty.} =
    ## similar to a unittest2.suite but without suiteSetup and suiteTeardown
    ## suites impose a barrier when using parallel execution
    block:
        template setup(setupBody: untyped) {.dirty, used.} =
            var dtestSetupIMPLFlag {.used.} = true
            template dtestSetupIMPL: untyped {.dirty.} = setupBody

        template teardown(teardownBody: untyped) {.dirty, used.} =
            var dtestTeardownIMPLFlag {.used.} = true
            template dtestTeardownIMPL: untyped {.dirty.} = teardownBody
        
        body
