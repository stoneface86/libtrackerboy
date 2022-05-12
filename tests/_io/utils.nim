
import ../../src/trackerboy/[data, io, version]
import ../unittest_wrapper
import std/streams

export data
export io
export streams
export unittest_wrapper


proc corruptSignature*(strm: Stream) =
    strm.setPosition(0)
    var data: byte
    strm.read(data)
    data = not data
    strm.setPosition(0)
    strm.write(data)

proc overwriteRevMajor*(strm: Stream, major: uint8) =
    strm.setPosition(24) # seek to revMajor
    strm.write(major)    # overwrite with the given major


template pieceTests*(
    correctData: ModulePiece,
    correctBin: string,
    setupBody: untyped
    ): untyped =
    
    type PieceType = correctData.typeOf

    setup:
        var strm {.inject.} = newStringStream()
        setupBody
    
    test "deserialize":
        strm.write(correctBin)
        strm.setPosition(0)

        var dataIn = PieceType.init()
        let res = dataIn.deserialize(strm)
        check res == frNone
        if res == frNone:
            check dataIn == correctData

    test "deserialize - bad signature":
        strm.write(correctBin)
        corruptSignature(strm)
        strm.setPosition(0)
        var dataIn = PieceType.init()
        check dataIn.deserialize(strm) == frInvalidSignature

    test "deserialize - bad revision":
        strm.write(correctBin)
        overwriteRevMajor(strm, fileMajor + 1)
        strm.setPosition(0)
        var dataIn = PieceType.init()
        check dataIn.deserialize(strm) == frInvalidRevision
        # piece files were introduced in major 1, so a rev 0 file should not exist
        overwriteRevMajor(strm, 0)
        strm.setPosition(0)
        check dataIn.deserialize(strm) == frInvalidRevision

    test "serialize":
        let res = correctData.serialize(strm)
        check res == frNone
        if res == frNone:
            strm.setPosition(0)
            check correctBin == strm.readAll()

    test "persistance":
        let serializeRes = correctData.serialize(strm)
        check serializeRes == frNone
        if serializeRes == frNone:
            strm.setPosition(0)
            var dataIn = PieceType.init()
            let deserializeRes = dataIn.deserialize(strm)
            check deserializeRes == frNone
            if deserializeRes == frNone:
                check correctData == dataIn


