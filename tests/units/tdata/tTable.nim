
import ../testing
import libtrackerboy/data

testclass "Table"

const testName {.used.} = "test name"

dtest "can name instruments/waveforms":
    template nameTest(T: typedesc[Instrument|Waveform]) =
        block:
            var item = T.init
            check item.name.len() == 0
            item.name = testName
            check item.name == testName
    nameTest(Instrument)
    nameTest(Waveform)

testgroup:

    setup:
        var itable = InstrumentTable.init
        var wtable = WaveformTable.init

    template ttest(testname: string, impl: untyped) =
        dtest testname:
            template testImpl(table {.inject.}: untyped) =
                impl
            testImpl(itable)
            testImpl(wtable)

    ttest "table is empty on init":
        check table.len == 0
        for id in TableId.low..TableId.high:
            check table[id] == nil
    
    ttest "duplicate":
        let srcId = table.add()
        var src = table[srcId]
        
        check src != nil
        src[].name = testName

        when src[] is Instrument:
            src.envelope = 0x03
            src.initEnvelope = true
            src.sequences[skPanning].data = @[1u8, 1, 2, 2, 3]
        else:
            src.data = "0123456789ABCDEFFEDCBA9876543210".parseWave

        let dupId = table.duplicate(srcId)
        var duped = table[dupId]
        check:
            duped != nil
            src[] == duped[]

    ttest "keeps track of the next available id":
        check:
            table.nextAvailableId == 0
            table.nextAvailableId == table.add()
            table.nextAvailableId == 1
            table.nextAvailableId == table.add()
            table.nextAvailableId == 2
            table.nextAvailableId == table.add()
        
        table.remove(0)
        check table.nextAvailableId == 0
        table.remove(1)
        check table.nextAvailableId == 0

        check:
            table.nextAvailableId == table.add()
            table.nextAvailableId == 1
            table.nextAvailableId == table.add()
            table.nextAvailableId == 3