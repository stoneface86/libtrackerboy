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
#include "trackerboy/apu/IApuIo.hpp"

#include <cstdint>
#include <cstddef>


namespace trackerboy {


//
// Apu abstract base class
//
class Apu : public IApuIo {

public:

    virtual ~Apu() = default;

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
    // Gets the current volume level (0-F) for a channel. Used for
    // visualization purposes only.
    //
    // Base implementation always returns 0
    //
    virtual int channelVolume(ChType ch);

};


}
