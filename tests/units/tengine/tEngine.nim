
import libtrackerboy/[data, engine]
import ../testing

testclass "Engine"

dtest "play raises AssertionDefect on nil song":
  var engine = Engine.init()
  expect AssertionDefect:
    engine.play(toImmutable[ref Song](nil))

dtest "play raises IndexDefect on invalid pattern index":
  var engine = Engine.init()
  var song = Song.new()
  expect IndexDefect:
    engine.play(song.toImmutable, song.order.len)

dtest "play raises IndexDefect on invalid row index":
  var engine = Engine.init()
  var song = Song.new()
  expect IndexDefect:
    engine.play(song.toImmutable, 0, song[].trackLen)
