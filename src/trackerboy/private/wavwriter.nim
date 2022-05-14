##[

.. include:: warning.rst

]##

import ../common
import endian
export PcmF32

import std/[streams, with]

type

    WavWriter* {.requiresInit.} = object
        stream: FileStream
        channels: int
        samplerate: int
        samplesWritten: int

    # Wav header structure
    # [C] indicates the field is set on close
    # [I] indicates the field is set on init

    u32le = LittleEndian[uint32]

    WavHeader {.packed.} = object
        riffId: array[4, char]      # = "RIFF"
        chunkSize: u32le            # = [C]
        waveId: array[4, char]      # = "WAVE"
        # fmt subchunk
        fmtId: array[4, char]       # = "fmt "
        fmtChunkSize: u32le         # = 18
        fmtTag: uint16              # = 3 (IEEE_FLOAT)
        fmtChannels: uint16         # [I]
        fmtSampleRate: u32le        # [I]
        fmtAvgBytesPerSec: u32le    # [I] = sizeof(Sample) * fmtSampleRate * fmtChannels
        fmtBlockAlign: uint16       # [I] = sizeof(Sample) * fmtChannels
        fmtBitsPerSample: uint16    # = sizeof(Sample) * 8
        fmtCbSize: uint16           # = 0
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

proc initWavWriter*(filename: sink string, channels, samplerate: int): WavWriter =
    result = WavWriter(
        stream: openFileStream(filename, fmWrite),
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
        fmtTag: 3,
        fmtChannels: channels.uint16,
        fmtSampleRate: samplerate.uint32.toLE,
        fmtAvgBytesPerSec: (bytesPerChannel * samplerate).uint32.toLE,
        fmtBlockAlign: bytesPerChannel.uint16,
        fmtBitsPerSample: sizeof(PcmF32) * 8,
        fmtCbSize: 0,
        factId: ['f', 'a', 'c', 't'],
        factChunkSize: 4'u32.toLE,
        factSampleCount: 0'u32.toLE,
        dataId: ['d', 'a', 't', 'a'],
        dataChunkSize: 0'u32.toLE
    )

    result.stream.write(header)

proc close(w: var WavWriter) =
    if w.stream != nil:
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
            w.stream.write(0u8)
            inc chunkSize
        
        with w.stream:
            # overwrite the chunk size for the entire file (also equal to filesize - 8)
            setPosition(offsetOf(WavHeader, chunkSize))
            write(chunkSize.toLE)

            # overwrite the sample count in the fact subchunk
            setPosition(offsetOf(WavHeader, factSampleCount))
            write(totalSamples.toLE)

            # overwrite the chunk size of the data subchunk
            setPosition(offsetOf(WavHeader, dataChunkSize))
            write(dataChunkSize.toLE)

        w.stream = nil

#
# Writes the sampled data in the given array to the file
#
proc write*(w: var WavWriter, data: openArray[PcmF32]) =
    let samples = data.len div w.channels
    w.stream.writeData(unsafeAddr(data), sizeof(PcmF32) * samples * w.channels)
    w.samplesWritten += samples
