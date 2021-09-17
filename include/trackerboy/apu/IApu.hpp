/*
** Trackerboy - Gameboy / Gameboy Color music tracker
** Copyright (C) 2019-2021 stoneface86
**
** Permission is hereby granted, free of charge, to any person obtaining a copy
** of this software and associated documentation files (the "Software"), to deal
** in the Software without restriction, including without limitation the rights
** to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
** copies of the Software, and to permit persons to whom the Software is
** furnished to do so, subject to the following conditions:
**
** The above copyright notice and this permission notice shall be included in all
** copies or substantial portions of the Software.
**
** THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
** IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
** FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
** AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
** LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
** OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
** SOFTWARE.
**
*/

#pragma once

#include "trackerboy/trackerboy.hpp"

#include <cstdint>
#include <cstddef>


namespace trackerboy {


//
// Apu interface
//
class IApu {

public:

    enum Reg {
        // CH1 - Square 1 --------------------------------------------------------
        REG_NR10 = 0x10, // -PPP NSSS | sweep period, negate, shift
        REG_NR11 = 0x11, // DDLL LLLL | duty, length
        REG_NR12 = 0x12, // VVVV APPP | envelope volume, mode, period
        REG_NR13 = 0x13, // FFFF FFFF | Frequency LSB
        REG_NR14 = 0x14, // TL-- -FFF | Trigger, length enable, freq MSB
        // CH2 - Square 2 --------------------------------------------------------
        REG_UNUSED1 = 0x15,
        REG_NR21 = 0x16, // DDLL LLLL | duty, length
        REG_NR22 = 0x17, // VVVV APPP | envelope volume, mode, period
        REG_NR23 = 0x18, // FFFF FFFF | frequency LSB
        REG_NR24 = 0x19, // TL-- -FFF | Trigger, length enable, freq MSB
        // CH3 - Wave ------------------------------------------------------------
        REG_NR30 = 0x1A, // E--- ---- | DAC Power
        REG_NR31 = 0x1B, // LLLL LLLL | length
        REG_NR32 = 0x1C, // -VV- ---- | wave volume
        REG_NR33 = 0x1D, // FFFF FFFF | frequency LSB
        REG_NR34 = 0x1E, // TL-- -FFF | Trigger, length enable, freq MSB
        // CH4 - Noise -----------------------------------------------------------
        REG_UNUSED2 = 0x1F,
        REG_NR41 = 0x20, // --LL LLLL | length
        REG_NR42 = 0x21, // VVVV APPP | envelope volume, mode, period
        REG_NR43 = 0x22, // SSSS WDDD | clock shift, width, divisor mode
        REG_NR44 = 0x23, // TL-- ---- | trigger, length enable
        // Control/Status --------------------------------------------------------
        REG_NR50 = 0x24, // ALLL BRRR | Terminal enable/volume
        REG_NR51 = 0x25, // 4321 4321 | channel terminal enables
        REG_NR52 = 0x26, // P--- 4321 | Power control, channel len. stat
        // Wave RAM
        REG_WAVERAM = 0x30
    };

    virtual ~IApu() = default;


    //
    // Begins a new frame of emulation. Must be called before step and endFrameAt.
    // The internal sample buffer is cleared.
    //
    virtual void beginFrame() = 0;

    //
    // Step the emulator for the given number of cycles. Note that the cycles
    // parameter is in T-states not M-cycles, so if stepping after a NOP instruction
    // you would call step(4) not step(1).
    //
    virtual void step(uint32_t cycles) = 0;

    //
    // Ends the frame at the given cycle time, samples can now
    // read from readSamples().
    //
    virtual void endFrameAt(uint32_t time) = 0;

    //
    // Gets the number of samples to be read out
    //
    virtual size_t samplesAvailable() = 0;

    //
    // Reads the given number of samples into the given buffer, buf.
    // The number of samples that was actually read is returned.
    //
    virtual size_t readSamples(float *buf, size_t samples) = 0;

    //
    // Sets the size of the APU's internal audio buffer
    //
    virtual void setBuffer(size_t samples) = 0;

    //
    // Sets the samplerate of the generated audio.
    //
    virtual void setSamplerate(int rate) = 0;

    //
    // Hardware reset of the APU, buffer is also cleared.
    //
    virtual void reset() = 0;

    //
    // Performs an APU register read for the given register. The
    // data from the read is returned. 0 should be returned for any
    // unknown register.
    //
    virtual uint8_t readRegister(uint8_t reg) = 0;

    //
    // Performs an APU register write for the given register and value.
    // The write should be ignored for any unknown register.
    //
    virtual void writeRegister(uint8_t reg, uint8_t value) = 0;

    //
    // Gets the current volume level (0-F) for a channel. Used for
    // visualization purposes only.
    //
    // Base implementation always returns 0
    //
    virtual int channelVolume(ChType ch);

};


}
