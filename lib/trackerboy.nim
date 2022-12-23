# exported C interface for libtrackerboy

import modules/[
    notes,
    version
]
export notes, version

proc NimMain() {.importc, cdecl.}

{.push exportc, noconv.}

proc ltbInit*(): cint =
    NimMain()
    0

{.pop.}
