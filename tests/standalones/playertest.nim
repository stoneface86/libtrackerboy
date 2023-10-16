
when NimMajor >= 2:
  import std/cmdline
else:
  import std/os

import std/[exitprocs, streams, strformat, strutils]

import libtrackerboy/[data, engine, io]
import libtrackerboy/private/player

proc test(song: Immutable[ref Song]; module: Module; loop: Natural): int =
  const frameLimit = 214920 # ~ 1 hour @ 59.7 Hz
  
  var 
    player = Player.init(song, loop)
    engine = Engine.init()
  engine.play(song)
  player.play(engine, module.instruments):
    inc result
    if result >= frameLimit:
      return -1
  #echo "Played the song 2 times in " & $frames & " frames"

proc main(): int =
  if paramCount() notin 1..2:
    stderr.write("usage: playertest <modulefile> [song]\n")
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

  const loopCount = 2
  let frameCount = test(srcMod.songs[songIndex].toImmutable, srcMod, loopCount)
  if frameCount == -1:
    write(stderr, "frame limit reached! Stopping.\n")
    return 1
  else:
    echo &"Played the song {loopCount} time(s) in {frameCount} frames."


  
when isMainModule:
  setProgramResult( main() )