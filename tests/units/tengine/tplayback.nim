
#import libtrackerboy/private/hardware 
#import libtrackerboy/[notes]
import libtrackerboy/private/[enginestate]
import utils
import ../testing

#import std/[with]

testclass "playback"

# these test the behavior of the engine. Sample module data is played and
# diagnostic data from the engine is checked, or the writes made to the
# apu.

dtest "empty pattern":
  var eh = EngineHarness.init()
  eh.play()
  for i in 0..32:
    eh.step()
    check:
      eh.engine.takeOperation() == ApuOperation.default
      eh.currentFrame().time == i

dtest "speed timing":
  proc speedtest(expected: openarray[bool], speed: Speed) =
    const testAmount = 5
    var eh = EngineHarness.init()
    checkpoint "speed = " & $speed
    eh.song.speed = speed
    eh.play()
    for i in 0..<testAmount:
      for startedNewRow in expected:
        eh.frameTest(f):
          check:
            f.speed == speed
            f.startedNewRow == startedNewRow

  speedtest([true],  0x10)
  speedtest([true, false, false, true, false], 0x28)
  speedtest([true, false, false, false, false, false], 0x60)

dtest "song looping":
  var eh = EngineHarness.init()
  eh.setupSong(s):
    s.speed = unitSpeed
    s.trackLen = 1
    s.order.setLen(3)
  eh.play()
  eh.frameTest(f):
    check f.order == 0
  eh.frameTest(f):
    check:
      f.order == 1
      f.startedNewPattern
  eh.frameTest(f):
    check:
      f.order == 2
      f.startedNewPattern
  eh.frameTest(f):
    check:
      f.order == 0
      f.startedNewPattern


  

