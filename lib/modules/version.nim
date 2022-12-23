import libtrackerboy/version as ltb_version

{.push exportc, noconv.}

let versionStr = static: ($currentVersion).cstring

func tbVersionMajor*(): cint = currentVersion.major.cint
func tbVersionMinor*(): cint = currentVersion.minor.cint
func tbVersionPatch*(): cint = currentVersion.patch.cint
proc tbVersionString*(): cstring = versionStr

func tbVersionFileMajor*(): cint = currentFileMajor
func tbVersionFileMinor*(): cint = currentFileMinor

{.pop.}
