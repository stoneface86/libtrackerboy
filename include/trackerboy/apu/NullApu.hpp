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

/*!
 * \file NullApu.hpp
 * \brief NullApu class definition
 */

#include "trackerboy/apu/Apu.hpp"

namespace trackerboy {

/*!
 * \brief An Apu implementation that does nothing
 *
 * The NullApu provides an Apu in which IO operations are ignored, and
 * no audio samples are ever generated.
 */
class NullApu final : public Apu {

public:

    /*!
     * \brief implementation does nothing
     * \param cycles ignored
     */
    virtual void step(uint32_t cycles) override;

    /*!
     * \brief implementation does nothing
     * \param time ignored
     */
    virtual void endFrameAt(uint32_t time) override;

    /*!
     * \brief implementation does nothing
     * \return always 0
     */
    virtual size_t samplesAvailable() override;

    /*!
     * \brief implementation does nothing
     * \param buf ignored
     * \param samples ignored
     * \return always 0
     */
    virtual size_t readSamples(float *buf, size_t samples) override;

    /*!
     * \brief implementation does nothing
     * \param samples ignored
     */
    virtual void setBuffer(size_t samples) override;

    /*!
     * \brief implementation does nothing
     * \param rate ignored
     */
    virtual void setSamplerate(int rate) override;

    /*!
     * \brief implementation does nothing
     */
    virtual void reset() override;

    /*!
     * \brief implementation does nothing
     * \param reg ignored
     * \return always 0
     */
    virtual uint8_t readRegister(uint8_t reg) override;

    /*!
     * \brief implementation does nothing
     * \param reg ignored
     * \param value ignored
     */
    virtual void writeRegister(uint8_t reg, uint8_t value) override;

};


}
