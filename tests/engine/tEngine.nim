
import trackerboy/[data, engine]
import ../testing

testclass "Engine"

func makeEngine(): Engine =
    result = Engine.init()
    result.module = Module.new.toImmutable

dtest "play raises AssertionDefect on nil module":
    var engine = Engine.init()
    expect AssertionDefect:
        engine.play()

dtest "play raises IndexDefect on invalid song index":
    var engine = makeEngine()
    expect IndexDefect:
        engine.play(engine.module[].songs.len)

dtest "play raises IndexDefect on invalid pattern index":
    var engine = makeEngine()
    expect IndexDefect:
        engine.play(0, engine.module[].songs[0][].order.len)

dtest "play raises IndexDefect on invalid row index":
    var engine = makeEngine()
    expect IndexDefect:
        engine.play(0, 0, engine.module[].songs[0][].trackLen)
