import libtrackerboy/version as ltb_version

{.push exportc, noconv.}

let versionStr = static: ($currentVersion).cstring

func ltbVersionMajor*(): cint = currentVersion.major.cint
func ltbVersionMinor*(): cint = currentVersion.minor.cint
func ltbVersionPatch*(): cint = currentVersion.patch.cint
proc ltbVersionString*(): cstring = versionStr

func ltbVersionFileMajor*(): cint = currentFileMajor
func ltbVersionFileMinor*(): cint = currentFileMinor

{.pop.}
