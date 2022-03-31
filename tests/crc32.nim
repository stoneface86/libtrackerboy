##
## CRC32 calculation
## adapted from https://rosettacode.org/wiki/CRC-32#Nim
## 

type Crc32* = uint32
const InitCrc32 = Crc32(0xffffffff)

proc createCrcTable(): array[256, Crc32] =
    for i in 0..255:
        var rem = Crc32(i)
        for j in 0..7:
            if (rem and 1) > 0:
                rem = (rem shr 1) xor Crc32(0xedb88320)
            else: 
                rem = rem shr 1
        result[i] = rem

# Table created at compile time
const crc32table = createCrcTable()

proc accumulate(crc: Crc32, data: byte): Crc32 =
    (crc shr 8) xor crc32table[(crc and 0xff) xor data]

proc accumulate[T: not byte](crc: Crc32, data: T): Crc32 =
    result = crc
    for b in cast[array[sizeof(T), byte]](data):
        result = result.accumulate(b)

proc crc32*(data: string): Crc32 =
    result = InitCrc32
    for ch in data:
        result = result.accumulate(ch.byte)
    result = not result

proc crc32*[T](data: openarray[T]): Crc32 =
    result = InitCrc32
    for item in data:
        result = result.accumulate(item)
    result = not result

static:
    assert crc32("The quick brown fox jumps over the lazy dog") == 0x414FA339
