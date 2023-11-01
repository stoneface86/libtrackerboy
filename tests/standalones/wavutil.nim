
when NimMajor >= 2:
  import std/cmdline
else:
  import std/os

import std/[exitprocs, os, streams, strutils]

import libtrackerboy/[data, engine, io]
import libtrackerboy/exports/wav


proc main(): int =
  if paramCount() notin 1..2:
    stderr.write("usage: wavutil <modulefile> [song]\n")
    return 2

  let songIndex = block:
    if paramCount() == 2:
      try:
        parseInt(paramStr(2))
      except ValueError:
        stderr.write("error: invalid number for [song]\n")
        return 2
    else:
      0

  var srcMod = Module.init()
  var strm = newFileStream(paramStr(1), fmRead)
  if strm == nil:
    stderr.write("error: could not open module\n")
    return 1
  let err = srcMod.deserialize(strm)
  if err != frNone:
    stderr.write("error: failed to read module: " & $err)
    stderr.write('\n')
    return 1
  strm.close()

  let outDir = getAppDir().joinPath("wavutil.d")
  outDir.createDir()

  var config = WavConfig.init()
  config.song = songIndex
  config.duration = songDuration(2)
  config.filename = outDir / "output.wav"
  srcMod.exportWav(config)


  
when isMainModule:
  setProgramResult( main() )