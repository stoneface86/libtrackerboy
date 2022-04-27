##
## Module for reading/writing io blocks from a stream. A block is tagged data
## with a size, similar to TLV. Each block begins with a 4-byte identifier,
## followed by a 4-byte size, followed by the data. The identifier and size of
## the block are stored in little endian.
## 
## An InputBlock is used to read a block, and to ensure that no data is
## read past the size of the block.
## 
## An OutputBlock is used to write the block, keeping track of the block's size
## whenever data is written to it.
## 


import std/streams
export streams

import endian

type
    BlockId* = uint32
    BlockSize* = uint32

    InputBlock* {.requiresInit.} = object
        stream: Stream
        avail: int
        size: int

    OutputBlock* {.requiresInit.} = object
        stream: Stream
        lengthPos: int
        size: int

func toBlockId*(str: string): BlockId {.compileTime.} =
    result = (str[3].ord.BlockId shl 24) or
             (str[2].ord.BlockId shl 16) or
             (str[1].ord.BlockId shl 8) or
             (str[0].ord.BlockId)

proc begin*(b: var InputBlock): BlockId =
    # read the block type, put into result
    var id: LittleEndian[BlockId]
    b.stream.read(id)
    result = id.toNE()
    # read the block size
    var size: LittleEndian[BlockSize]
    b.stream.read(size)
    b.avail = size.toNE().int
    b.size = b.avail

func isFinished*(b: InputBlock): bool =
    b.avail == 0

func initInputBlock*(stream: Stream): InputBlock =
    InputBlock(
        stream: stream,
        avail: 0,
        size: 0
    )

func size*(ib: InputBlock): int =
    ib.size

proc readData*(b: var InputBlock, data: pointer, size: Natural): bool =
    if size > b.avail:
        return true
    let amountRead = b.stream.readData(data, size)
    if amountRead != size:
        # unlikely, but consider this an invalid read if it happens
        return true
    b.avail -= size

proc read*[T: not openarray](b: var InputBlock, val: var T): bool =
    b.readData(val.addr, T.sizeof)

proc read*[T](b: var InputBlock, buf: var openarray[T]): bool =
    if buf.len > 0:
        b.readData(buf[0].addr, buf.len * T.sizeof)
    else:
        false

func initOutputBlock*(stream: Stream): OutputBlock =
    OutputBlock(
        stream: stream,
        lengthPos: 0,
        size: 0
    )

proc begin*(b: var OutputBlock, blockId: BlockId) =
    b.stream.write(blockId.toLE)

    b.lengthPos = b.stream.getPosition()
    let size: BlockSize = 0
    b.stream.write(size)

    b.size = 0

proc finish*(b: var OutputBlock) =
    if b.size > 0:
        let oldpos = b.stream.getPosition()
        b.stream.setPosition(b.lengthPos)
        let size = toLE(b.size.BlockSize)
        b.stream.write(size)
        b.stream.setPosition(oldpos)

proc writeData*(b: var OutputBlock, data: pointer, size: Natural) =
    b.stream.writeData(data, size)
    b.size += size

proc write*[T: not openarray](b: var OutputBlock, data: T) =
    b.stream.write(data)
    b.size += data.sizeof

proc write*[T](b: var OutputBlock, data: openarray[T]) =
    if data.len > 0:
        b.writeData(data[0].unsafeAddr, data.len * T.sizeof)
