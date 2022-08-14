##[

.. include:: warning.rst

]##

import ../common, endian
export PcmF32

import std/[with]

type

    WavWriter* {.requiresInit.} = object
        file: File
        channels: int
        samplerate: int
        samplesWritten: int

    # Wav header structure
    # [C] indicates the field is set on close
    # [I] indicates the field is set on init

    u32le = LittleEndian[uint32]
    u16le = LittleEndian[uint16]

    WavHeader {.packed.} = object
        riffId: array[4, char]      # = "RIFF"
        chunkSize: u32le            # = [C]
        waveId: array[4, char]      # = "WAVE"
        # fmt subchunk
        fmtId: array[4, char]       # = "fmt "
        fmtChunkSize: u32le         # = 18
        fmtTag: u16le               # = 3 (IEEE_FLOAT)
        fmtChannels: u16le          # [I]
        fmtSampleRate: u32le        # [I]
        fmtAvgBytesPerSec: u32le    # [I] = sizeof(Sample) * fmtSampleRate * fmtChannels
        fmtBlockAlign: u16le        # [I] = sizeof(Sample) * fmtChannels
        fmtBitsPerSample: u16le     # = sizeof(Sample) * 8
        fmtCbSize: u16le            # = 0
        # fact subchunk
        # for integer PCM this is not needed, but is needed for "all new WAVE formats"
        # it is assumed that float PCM requires this chunk
        factId: array[4, char]      # = "fact"
        factChunkSize: u32le        # = 4
        factSampleCount: u32le      # = [C]
        # data subchunk
        dataId: array[4, char]      # = "data"
        dataChunkSize: u32le        # = [C]
        # sampled data follows
        # extra padding byte if dataChunkSize is odd [C]


proc close*(w: var WavWriter): void

proc `=destroy`*(w: var WavWriter) =
    w.close()

proc checkedWriteBuffer(f: File, buffer: pointer, buflen: int) =
    if f.writeBuffer(buffer, buflen) != buflen:
        raise newException(IOError, "could not write entire buffer")

proc init*(_: typedesc[WavWriter], filename: sink string, channels, samplerate: int): WavWriter =
    result = WavWriter(
        file: open(filename, fmWrite),
        channels: channels,
        samplerate: samplerate,
        samplesWritten: 0
    )

    let bytesPerChannel = channels * sizeof(PcmF32)

    let header = WavHeader(
        riffId: ['R', 'I', 'F', 'F'],
        chunkSize: 0'u32.toLE,
        waveId: ['W', 'A', 'V', 'E'],
        fmtId: ['f', 'm', 't', ' '],
        fmtChunkSize: 18'u32.toLE,
        fmtTag: 3'u16.toLE,
        fmtChannels: channels.uint16.toLE,
        fmtSampleRate: samplerate.uint32.toLE,
        fmtAvgBytesPerSec: (bytesPerChannel * samplerate).uint32.toLE,
        fmtBlockAlign: bytesPerChannel.uint16.toLE,
        fmtBitsPerSample: (sizeof(PcmF32) * 8).uint16.toLE,
        fmtCbSize: 0'u16.toLE,
        factId: ['f', 'a', 'c', 't'],
        factChunkSize: 4'u32.toLE,
        factSampleCount: 0'u32.toLE,
        dataId: ['d', 'a', 't', 'a'],
        dataChunkSize: 0'u32.toLE
    )

    result.file.checkedWriteBuffer(header.unsafeAddr, header.sizeof)

proc write[T: SomeWord](f: File, i: LittleEndian[T]) =
    f.checkedWriteBuffer(i.unsafeAddr, T.sizeof)

proc close(w: var WavWriter) =
    if w.file != nil:
        let totalSamples = w.samplesWritten.uint32
        let dataChunkSize = totalSamples * w.channels.uint32 * sizeof(PcmF32).uint32

        # chunk size totals
        # 4: riff chunk
        # 18 + 8: fmt chunk
        # 4 + 8: fact chunk
        # = 42
        # 8 + dataChunkSize + pad byte?
        var chunkSize = 50 + dataChunkSize

        # do we need a pad byte?
        if (dataChunkSize and 1) == 1:
            w.file.write('\0')
            inc chunkSize
        
        with w.file:
            # overwrite the chunk size for the entire file (also equal to filesize - 8)
            setFilePos(offsetOf(WavHeader, chunkSize))
            write(chunkSize.toLE)

            # overwrite the sample count in the fact subchunk
            setFilePos(offsetOf(WavHeader, factSampleCount))
            write(totalSamples.toLE)

            # overwrite the chunk size of the data subchunk
            setFilePos(offsetOf(WavHeader, dataChunkSize))
            write(dataChunkSize.toLE)

        w.file = nil

#
# Writes the sampled data in the given array to the file
#
proc write*(w: var WavWriter, data: openArray[PcmF32]) =
    let samples = data.len div w.channels
    when cpuEndian == littleEndian:
        w.file.checkedWriteBuffer(data.unsafeAddr, PcmF32.sizeof * samples * w.channels)
    else:
        for sample in data:
            w.file.write(toLE(cast[uint32](sample)))
    w.samplesWritten += samples
