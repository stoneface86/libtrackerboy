discard """
"""

import ../../src/trackerboy/data
import ../unittest_wrapper

import std/sequtils

const testrow1: OrderRow = [1u8, 1, 1, 1]
const testrow2: OrderRow = [2u8, 2, 2, 2]

unittests:
    suite "Order":

        setup:
            var order = initOrder()

        test "must have 1 row on init":
            check:
                order.len == 1
                order[0] == default(OrderRow)

        test "get/set":
            order[0] = testrow1
            check order[0] == testrow1

        test "insert":
            order.insert(testrow1, 1)
            check:
                order[0] == default(OrderRow)
                order[1] == testrow1

            order.insert(testrow2, 0)
            check:
                order[0] == testrow2
                order[1] == default(OrderRow)
                order[2] == testrow1

        test "auto-row":
            for i in 1u8..5u8:
                order.insert(order.nextUnused(), order.len)
                check order[i.ByteIndex] == [i, i, i, i]

        test "resizing":
            order.setLen(5)
            check:
                order.len == 5
                order.data.all(proc (o: OrderRow): bool = o == default(OrderRow))

            order[0] = testrow1
            order[1] = testrow2
            order.setLen(2)
            doAssert order.len == 2
            doAssert order[0] == testrow1
            doAssert order[1] == testrow2
