discard """
"""

import ../../src/trackerboy/data
import ../unittest_wrapper

unittests:

    suite "SongList":

        setup:
            var songlist = SongList.init
        
        test "1 song on init":
            check songlist.len == 1
            check songlist[0] != nil

        test "get/set":
            var song = Song.new
            check songlist[0] != nil
            songlist[0] = song
            check songlist[0] == song
        
        test "add":
            songlist.add()
            check songlist.len == 2
            songlist.add()
            check songlist.len == 3
            songlist.add()
            check songlist.len == 4

        test "duplicate":
            songlist[0].rowsPerBeat = 8
            songlist.duplicate(0)
            check songlist.len == 2
            check songlist[0][] == songlist[1][]
        
        test "remove":
            songlist.add()
            songlist.add()
            songlist.remove(0)
            check songlist.len == 2
            songlist.remove(1)
            check songlist.len == 1

        test "removing when len=1 raises InvalidOperationDefect":
            expect InvalidOperationDefect:
                songlist.remove(0)
        
        test "adding/duplicating when len=256 raises InvalidOperationDefect":
            for i in 0..254:
                songlist.add()
            expect InvalidOperationDefect:
                songlist.add()
            expect InvalidOperationDefect:
                songlist.duplicate(2)
