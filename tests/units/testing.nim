
import unittest2
export unittest2

import std/macros

macro checkout*(conds: varargs[untyped]): untyped =
  ## Same as unittest2.check, but will end the test if any of `conds` was `false`
  if conds[0].kind == nnkStmtList:
    result = newNimNode(nnkStmtList)
    for node in conds[0]:
      if node.kind != nnkCommentStmt:
        result.add(newCall(newIdentNode("checkout"), node))
  else:
    result = quote do:
      when not declared(testStatusIMPL):
        {.error: "you can only use this in a test!".}
      check `conds`
      if testStatusIMPL == FAILED:
        return

var testunitVar {.compileTime.} = ""
var testclassVar {.compileTime.} = ""

template testunit*(unit: string) =
  static: testunitVar = unit

template testclass*(prefix: string) =
  static: testclassVar = prefix


proc prefixName(name: string): string {.compileTime.} =
  proc addPrefix(str: var string, prefix: string) =
    if prefix != "":
      str.add(prefix)
      str.add('.')
  
  result.addPrefix(testunitVar)
  result.addPrefix(testclassVar)
  result.add(name)
    

template dtest*(name: static[string], body: untyped): untyped =
  # prefixed test, adds `testclass` to the name if set
  test prefixName(name):
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
      var dtestSetupIMPLFlag {.compileTime, used.} = true
      template dtestSetupIMPL: untyped {.dirty, used.} = setupBody

    template teardown(teardownBody: untyped) {.dirty, used.} =
      var dtestTeardownIMPLFlag {.compileTime, used.} = true
      template dtestTeardownIMPL: untyped {.dirty, used.} = teardownBody
    
    body
