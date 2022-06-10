discard """
"""

import ../../src/trackerboy/[data, engine]

import ../unittest_wrapper

unittests:
    suite "Engine":

        var module = Module.new()

        setup:
            var engine = Engine.init()
            engine.module = module.toCRef()

        test "play raises InvalidOperationDefect on nil module":
            engine.module = noRef(Module)
            expect InvalidOperationDefect:
                engine.play()
        
        test "play raises IndexDefect on invalid song index":
            expect IndexDefect:
                engine.play(module.songs.len())

        test "play raises IndexDefect on invalid pattern index":
            expect IndexDefect:
                engine.play(0, module.songs[0][].order.len)

        test "play raises IndexDefect on invalid row index":
            expect IndexDefect:
                engine.play(0, 0, module.songs[0][].trackLen())
