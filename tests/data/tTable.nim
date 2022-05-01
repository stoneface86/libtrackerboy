discard """
"""

import ../../src/trackerboy/data
import ../unittest_wrapper

const testName = "test name"


unittests:

    test "can name instruments/waveforms":
        template nameTest(T: typedesc[Instrument|Waveform]) =
            block:
                var item = when T is Instrument: initInstrument() else: initWaveform()
                check item.name.len() == 0
                item.name = testName
                check item.name == testName
        nameTest(Instrument)
        nameTest(Waveform)

    suite "Table[T]":

        setup:
            var itable = initTable[Instrument]()
            var wtable = initTable[Waveform]()

        template ttest(testname: string, impl: untyped) =
            test testname:
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