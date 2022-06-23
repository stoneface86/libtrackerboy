
import tbc
import ../testing
export testing, tbc

proc initHelper*(cmd: string): tuple[exitcode: ExitCodes, app: Tbc] =
    result.exitcode = init(result.app, cmd)

template withInitHelper*(cmd: string, body: untyped): untyped {.dirty.} =
    block:
        let (exitcode {.used.}, app {.used.}) = initHelper(cmd)
        body
