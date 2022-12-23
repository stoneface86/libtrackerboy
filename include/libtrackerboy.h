
// header file for the exported libtrackerboy C interface (libtrackerboyc.nim)

#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define TBAPI(ret, func) extern ret func

TBAPI(int, tbInit)(void);

// libtrackerboy/common

enum TbChannelId {
    tbCh1 = 0,
    tbCh2 = 1,
    tbCh3 = 2,
    tbCh4 = 3
};

enum TbMixMode {
    tbMixMute   = 0x0,
    tbMixLeft   = 0x1,
    tbMixRight  = 0x2,
    tbMixMiddle = tbMixLeft | tbMixRight
};

typedef float TbPcm;

// libtrackerboy/version

typedef struct {
    int major, minor, patch;
} TbVersion;

TBAPI(int, tbVersionMajor)(void);
TBAPI(int, tbVersionMinor)(void);
TBAPI(int, tbVersionPatch)(void);
TBAPI(TbVersion, tbVersion)(void);
TBAPI(const char*, tbVersionString)(void);
TBAPI(int, tbVersionFileMajor)(void);
TBAPI(int, tbVersionFileMinor)(void);

// libtrackerboy/notes

TBAPI(uint16_t, tbNotesLookupTone)(int note);
TBAPI(uint8_t, tbNotesLookupNoise)(int note);

enum {
    tbNoteToneLow = 0,
    tbNoteToneHigh = 83,
    tbNoteNoiseLow = 0,
    tbNoteNoiseHigh = 59,
    tbNoteCut = tbNoteToneHigh + 1
};

// libtrackerboy/apu

// incomplete type, the structure of TbApu is only known on the nim side
typedef struct TbApu TbApu;

TBAPI(TbApu*, tbApuInit)(int samplerate, double framerate);
TBAPI(void, tbApuUninit)(TbApu *apu);
TBAPI(void, tbApuReset)(TbApu *apu);
TBAPI(void, tbApuRun)(TbApu *apu, uint32_t cycles);
TBAPI(void, tbApuRunToFrame)(TbApu *apu);
TBAPI(uint8_t, tbApuReadRegister)(TbApu *apu, uint8_t reg);
TBAPI(void, tbApuWriteRegister)(TbApu *apu, uint8_t reg, uint8_t val);
TBAPI(uint32_t, tbApuTime)(TbApu const* apu);
TBAPI(int, tbApuAvailableSamples)(TbApu const* apu);
TBAPI(float const*, tbApuTakeSamples)(TbApu *apu, int *sampleCount);
TBAPI(void, tbApuRemoveSamples)(TbApu *apu);
TBAPI(void, tbApuSetSamplerate)(TbApu *apu, int samplerate);
TBAPI(void, tbApuSetBufferSize)(TbApu *apu, int size);
TBAPI(int, tbApuGetChannelFrequency)(TbApu const *apu, TbChannelId chid);
TBAPI(int, tbApuGetChannelVolume)(TbApu const *apu, TbChannelId chid);
TBAPI(TbMixMode, tbApuGetChannelMix)(TbApu const* apu, TbChannelId chid);

// libtrackerboy/apuio

// C enum equivalent of the apuio.ApuRegister enum
enum TbApuRegister {
    // CH1
    rNR10 = 0x10, rNR11, rNR12, rNR13, rNR14,
    // CH2
    rNR21 = 0x16, rNR22, rNR23, rNR24,
    // CH3
    rNR30 = 0x1A, rNR30, rNR31, rNR32, rNR33, rNR34,
    // CH4
    rNR41 = 0x20, rNR42, rNR43, rNR44,
    // Control/Status
    rNR50 = 0x24, rNR51, rNR52,
    rWAVERAM = 0x30
}

#ifdef __cplusplus
}
#endif
