discard """
"""

import ../../src/trackerboy/private/ioblocks
import ../unittest_wrapper
import std/streams

const testBlockId = "TEST".toBlockId
const testBlockData = ['e', 'x', 'a', 'm', 'p', 'l', 'e']

proc writeTestBlock(stream: Stream) =
    var ob = initOutputBlock(stream)
    ob.begin(testBlockId)
    ob.write(testBlockData)
    ob.finish()

unittests:
    suite "ioblocks":

        setup:
            var stream = newStringStream()

        test "persistance":

            type SampleObject = object
                a: int
                b: float
                c: array[3, char]
            
            const firstVal = 1
            const secondVal = SampleObject(
                a: 0, b: 23.5f, c: ['a', 'b', 'c']
            )
            const thirdVal = "just some string data..."

            const fourthVal = [1, 2, 3, 4]

            let fifthVal = @fourthVal

            block:
                var ob = initOutputBlock(stream)
                ob.begin(testBlockId)
                # generic overload
                ob.write(firstVal)
                ob.write(secondVal)
                # string overload
                ob.write(thirdVal)
                # test the openarray overloads
                ob.write(fourthVal)
                ob.write(fifthVal)
                ob.finish()

            stream.setPosition(0)
            block:
                var ib = initInputBlock(stream)
                check ib.begin() == testBlockId

                template testRead(expected: untyped): untyped =
                    block:
                        var val: expected.type
                        when expected.type is seq|string:
                            val.setLen(expected.len)
                        require not ib.read(val)
                        check val == expected
                testRead(firstVal)
                testRead(secondVal)
                testRead(thirdVal)
                testRead(fourthVal)
                testRead(fifthVal)
                check ib.isFinished()

        test "InputBlock returns true when reading past the block":
            writeTestBlock(stream)

            stream.setPosition(0)

            block:
                var ib = initInputBlock(stream)
                require ib.begin() == testBlockId
                # read all of the block
                var val: testBlockData.type
                require not ib.read(val)
                require ib.isFinished()
                # at the block end, attempting to read should fail
                let pos = stream.getPosition()
                var num: int
                check ib.read(num)
                # ensure that this attempt didn't alter the stream or block
                check ib.isFinished()
                check stream.getPosition() == pos

            stream.setPosition(0)
            block:
                var ib = initInputBlock(stream)
                require ib.begin() == testBlockId
                require not ib.isFinished()
                # at the start, attempt to read more than the block contains
                let pos = stream.getPosition()
                var data: array[testBlockData.len + 50, char]
                check ib.read(data)
                check not ib.isFinished()
                check stream.getPosition() == pos


        test "OutputBlock data format":
            writeTestBlock(stream)

            stream.setPosition(0)
            check stream.readAll() == "TEST\7\0\0\0example"

