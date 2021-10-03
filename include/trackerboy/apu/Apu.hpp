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

/*!
 * \file Apu.hpp
 * \brief Apu class definition
 */

#pragma once

#include "trackerboy/trackerboy.hpp"
#include "trackerboy/apu/IApuIo.hpp"

#include <cstdint>
#include <cstddef>


namespace trackerboy {


/*!
 * \brief Abstract base class for a gameboy APU emulator
 */
class Apu : public IApuIo {

public:

    virtual ~Apu() = default;


    /*!
     * \brief Steps the emulator for a given number of cycles
     * \param cycles the number of cycles (in T-states) to step
     *
     * The emulator is stepped for the given number of cycles.
     *
     * Note that the cycles parameter is in T-states and not M-cycles, so if
     * stepping after a NOP instruction you would call step(4) and not step(1).
     */
    virtual void step(uint32_t cycles) = 0;

    /*!
     * \brief Ends the frame at the given cycle time
     * \param time the time in cycles to end the frame
     * \sa samplesAvailable(), readSamples(float *buf, size_t samples)
     *
     * In order for samples to be read out, you must call this function at
     * a desired cycle time. The emulator is stepped to this point in time,
     * and audio samples are made available to be read out via readSamples()
     */
    virtual void endFrameAt(uint32_t time) = 0;

    /*!
     * \brief retrieves the number of samples available in the APU's buffer
     * \return The number of samples that can be read out
     * \sa readSamples(float *buf, size_t samples)
     */
    virtual size_t samplesAvailable() = 0;

    /*!
     * \brief Read from the APU's sample buffer
     * \param buf the destination buffer, dimension must be >= samples * 2
     * \param samples the maximum number of samples to read
     * \return the number of samples that were actually read
     * \sa samplesAvailable()
     *
     * Moves audio sample data from this APU's internal buffer to a given buffer.
     * Calling this function removes the samples in the buffer, so that new
     * samples can take their place.
     *
     * If the given number of samples to read is larger than the number of
     * available samples, then only what's available is read out.
     *
     * Note that the destination buffer is a stereo-interleaved audio buffer
     * of 32-bit float PCM samples. The size of the buffer must be >= samples * 2
     * or undefined behavior may occur.
     */
    virtual size_t readSamples(float *buf, size_t samples) = 0;

    /*!
     * \brief Set the size of the APU's sample buffer
     * \param samples size of the buffer, in samples
     *
     * Changes the size of the internal sample buffer. Some
     * implementations may require you to call this function once before using
     * any other functions.
     *
     * It is assumed that the contents of the current buffer are destroyed when
     * changing the size, but this is implementation-specific. So it is
     * recommended to empty the buffer first by reading samples or by clearing
     * it.
     */
    virtual void setBuffer(size_t samples) = 0;

    /*!
     * \brief set the samplerate of the generated audio
     * \param rate the rate, in hertz, must be > 0
     *
     * It is recommended that you process the contents of the buffer before
     * changing the rate. Otherwise you will have audio data with different
     * rates.
     */
    virtual void setSamplerate(int rate) = 0;

    /*!
     * \brief Hardware reset the APU
     *
     * Also clears the buffer.
     */
    virtual void reset() = 0;

    /*!
     * \brief Gets the current volume level for a channel.
     * \param ch The channel's volume to query
     * \return the channel's volume level in range 0 to 15
     *
     * This function is to be used for visualization purposes only. Subclasses
     * may choose to ignore implementing this function.
     *
     * Base implementation always returns 0.
     */
    virtual int channelVolume(ChType ch);

};


}
