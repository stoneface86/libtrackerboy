
import ../testing
import trackerboy/data

testclass "SongList"

testgroup:

    setup:
        var songlist = SongList.init

    dtest "1 song on init":
        check songlist.len == 1
        check songlist[0] != nil

    dtest "get/set":
        var song = Song.new
        check songlist[0] != nil
        songlist[0] = song
        check songlist[0] == song

    dtest "add":
        songlist.add()
        check songlist.len == 2
        songlist.add()
        check songlist.len == 3
        songlist.add()
        check songlist.len == 4

    dtest "duplicate":
        songlist[0].rowsPerBeat = 8
        songlist.duplicate(0)
        check songlist.len == 2
        check songlist[0][] == songlist[1][]

    dtest "remove":
        songlist.add()
        songlist.add()
        songlist.remove(0)
        check songlist.len == 2
        songlist.remove(1)
        check songlist.len == 1

    dtest "removing when len=1 raises AssertionDefect":
        expect AssertionDefect:
            songlist.remove(0)

    dtest "adding/duplicating when len=256 raises AssertionDefect":
        for i in 0..254:
            songlist.add()
        expect AssertionDefect:
            songlist.add()
        expect AssertionDefect:
            songlist.duplicate(2)
