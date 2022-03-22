{.used.}

import std/[unittest, sequtils]

import trackerboy/data

const
    testName = "test name"

test "can name instruments/waveforms":

    template nameTest(item: untyped) =
        check item.name.len() == 0
        item.name = testName
        check item.name == testName

    var instrument = initInstrument()
    nameTest(instrument)
    var waveform = initWaveform()
    nameTest(waveform)

test "initial Table[T] is empty":
    template ttest(T: type) =
        let table = initTable[T]()
        check table.size() == 0
        for id in TableId.low..TableId.high:
            check table[id] == nil
    ttest(Instrument)
    ttest(Waveform)

test "Table[T] duplicates item":

    template ttest(T: type) =
        var table = initTable[T]()
        let srcId = table.add()
        var src = table[srcId]
        
        check src != nil
        src[].name = testName

        when T is Instrument:
            src[].envelope = 0x03
            src[].initEnvelope = true
            src[][SequenceKind.panning].data = @[1u8, 1u8, 2u8, 2u8, 3u8]
        else:
            src[].data = "0123456789ABCDEFFEDCBA9876543210"

        let dupId = table.duplicate(srcId)
        var duped = table[dupId]
        check duped != nil
        check src[] == duped[]

    ttest(Instrument)
    ttest(Waveform)

test "Table[T] keeps track of next available id":
    var table = initTable[Instrument]()

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

    check table.nextAvailableId == table.add()
    check table.nextAvailableId == 1
    check table.nextAvailableId == table.add()
    check table.nextAvailableId == 3

const defaultOrderRow = [0u8, 0u8, 0u8, 0u8]
const testrow1 = [1u8, 1u8, 1u8, 1u8]
const testrow2 = [2u8, 2u8, 2u8, 2u8]

suite "Order":

    setup:
        var order = initOrder()

    test "1 row on init":
        check:
            order.size == 1
            order[0] == defaultOrderRow

    test "get/set":
        check order[0] == defaultOrderRow
        order[0] = testrow1
        check order[0] == testrow1

    test "insert":
        order.insert(testrow1, 1)
        check:
            order[0] == defaultOrderRow
            order[1] == testrow1

        order.insert(testrow2, 0)
        check:
            order[0] == testrow2
            order[1] == defaultOrderRow
            order[2] == testrow1

    test "auto-row":
        for i in 1..5:
            order.insert(order.nextUnused(), order.size())
            check order[i] == [i.uint8, i.uint8, i.uint8, i.uint8]

    test "resizing":
        order.resize(5)
        check:
            order.size == 5
            order.data.all(proc (o: OrderRow): bool = o == defaultOrderRow)

        order[0] = testrow1
        order[1] = testrow2
        order.resize(2)
        check:
            order.size == 2
            order[0] == testrow1
            order[1] == testrow2
