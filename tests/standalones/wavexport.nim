

when isMainModule:
  import std/[os, macros, streams]
  import libtrackerboy/[data, io]
  import libtrackerboy/exports/wav
  
  let outDir = getAppDir().joinPath("wavexport.d")
  outDir.createDir()

  const bloopPath = getProjectPath() / "bloop.tbm"

  var bloopMod = initModule()
  var strm = newFileStream(bloopPath, fmRead)
  doAssert bloopMod.deserialize(strm) == frNone
  strm.close()

  var config = initWavConfig()
  config.duration = songDuration(1)
  config.filename = outDir / "bloop-stereo.wav"
  bloopMod.exportWav(config)
  config.isMono = true
  config.filename = outDir / "bloop-mono.wav"
  bloopMod.exportWav(config)
