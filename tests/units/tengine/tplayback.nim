
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
  testsetup
  engine.play(song.toImmutable)
  for i in 0..32:
    engine.step(instruments)
    check engine.takeOperation() == ApuOperation.default
    check engine.currentFrame().time == i

dtest "speed timing":
  proc speedtest(expected: openarray[bool], speed: Speed) =
    const testAmount = 5
    var engine = Engine.init()
    var instruments = InstrumentTable.init()
    checkpoint "speed = " & $speed
    let song = Song.new()
    song.speed = speed
    engine.play(song.toImmutable)
    for i in 0..<testAmount:
      for startedNewRow in expected:
        engine.step(instruments)
        let frame = engine.currentFrame()
        check frame.speed == speed
        check frame.startedNewRow == startedNewRow

  speedtest([true],  0x10)
  speedtest([true, false, false, true, false], 0x28)
  speedtest([true, false, false, false, false, false], 0x60)

dtest "song looping":
  testsetup
  song.speed = unitSpeed
  song.trackLen = 1
  song.order.setLen(3)
  engine.play(song.toImmutable)

  engine.step(instruments)
  check engine.currentFrame().order == 0
  engine.step(instruments)
  check engine.currentFrame().order == 1 and engine.currentFrame().startedNewPattern
  engine.step(instruments)
  check engine.currentFrame().order == 2 and engine.currentFrame().startedNewPattern
  engine.step(instruments)
  check engine.currentFrame().order == 0 and engine.currentFrame().startedNewPattern


  

