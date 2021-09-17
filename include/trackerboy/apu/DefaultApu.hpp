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

#include "trackerboy/apu/Apu.hpp"

#include <memory>


namespace trackerboy {

//
// Implementation for the built-in APU. Gameboy APU emulator with a
// goal of "close-enough" emulation and quality sound output.
//
class DefaultApu final : public Apu {

public:

    DefaultApu();

    virtual void beginFrame() override;

    virtual void step(uint32_t cycles) override;

    virtual void endFrameAt(uint32_t time) override;

    virtual size_t samplesAvailable() override;

    virtual size_t readSamples(float *buf, size_t samples) override;

    virtual void setBuffer(size_t samples) override;

    virtual void setSamplerate(int rate) override;

    virtual void reset() override;

    virtual uint8_t readRegister(uint8_t reg) override;

    virtual void writeRegister(uint8_t reg, uint8_t value) override;

private:

    struct Private;
    std::unique_ptr<Private> mD;

};


}
