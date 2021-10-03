/*
** Trackerboy - Gameboy / Gameboy Color music tracker
** Copyright (C) 2019-2020 stoneface86
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
 * \file Instrument.hpp
 * \brief Instrument class definition
 */

#include "trackerboy/trackerboy.hpp"
#include "trackerboy/data/Named.hpp"
#include "trackerboy/data/Sequence.hpp"

#include <array>
#include <cstdint>
#include <optional>

namespace trackerboy {


/*!
 * \brief Data class for a trackerboy instrument
 *
 * A trackerboy instrument contains an intial envelope setting and sequences.
 * If an envelope is enabled, it is applied the first frame the instrument is
 * triggerred.
 *
 * Sequences modulate a respective parameter such as pitch, panning etc. For
 * more details on sequences see the Sequence class.
 *
 * Instruments can also have a default channel setting, but this setting is
 * purely informational, as an instrument can be used on any channel.
 */
class Instrument : public Named {

public:

    /*!
     * \brief index for the arpeggio sequence
     */
    static constexpr size_t SEQUENCE_ARP = 0;

    /*!
     * \brief index for the panning sequence
     */
    static constexpr size_t SEQUENCE_PANNING = 1;

    /*!
     * \brief index for the pitch sequence
     */
    static constexpr size_t SEQUENCE_PITCH = 2;

    /*!
     * \brief index for the timbre sequence
     */
    static constexpr size_t SEQUENCE_TIMBRE = 3;

    /*!
     * \brief total number of sequences
     */
    static constexpr size_t SEQUENCE_COUNT = 4;

    /*!
     * \brief type alias for the sequence data
     */
    using SequenceArray = std::array<Sequence, SEQUENCE_COUNT>;

    /*!
     * \brief Default constructs an instrument.
     * The instrument is constructed with:
     *  - default channel: CH1
     *  - envelope disabled with envelope = 0
     *  - no sequence data for all sequences
     */
    Instrument();

    /*!
     * \brief Gets the default channel for this instrument
     * \return The channel identifier
     */
    ChType channel() const noexcept;

    /*!
     * \brief Determines if the intial envelope setting is enabled
     * \return true if enabled, false otherwise
     */
    bool hasEnvelope() const noexcept;

    /*!
     * \brief Gets the initial envelope setting
     * \return the initial envelope setting 0-255.
     *
     * Note: For envelope channels, this setting is written to the envelope
     * register. For the wave channel, this setting is a waveform id.
     */
    uint8_t envelope() const noexcept;

    /*!
     * \brief Gets the intial envelope setting as an optional
     * \return the envelope setting if envelope is enabled, std::nullopt
     *         otherwise
     */
    std::optional<uint8_t> queryEnvelope() const noexcept;

    /*!
     * \brief Gets access to all of the instrument's sequences
     * \return A reference to the instrument's sequence array
     */
    SequenceArray& sequences() noexcept;

    /*!
     * \brief Gets a read-only reference to all of the instrument's sequences
     * \return A const reference to the instrument's sequence array
     */
    SequenceArray const& sequences() const noexcept;

    /*!
     * \brief Gets an enumerator for the given sequence
     * \param parameter the index of the sequence
     * \return a sequence enumerator for the given sequence index
     */
    Sequence::Enumerator enumerateSequence(size_t parameter) const noexcept;

    /*!
     * \brief Accessor for a sequence via index
     * \param parameter the index of the sequence to access
     * \return a reference to the sequence
     */
    Sequence& sequence(size_t parameter) noexcept;

    /*!
     * \brief Read-only accessor for a sequence via index.
     * \param parameter the index of the sequence to access.
     * \return a const reference to the sequence
     */
    Sequence const& sequence(size_t parameter) const noexcept;

    /*!
     * \brief Sets the default channel for this instrument.
     * \param ch The channel to set.
     *
     * This setting has no effect on music playback, it is used for information
     * purposes and serves as the channel to use when previewing.
     */
    void setChannel(ChType ch) noexcept;

    /*!
     * \brief Sets the initial envelope setting
     * \param value the envelope to set
     *
     * The envelope does not have to be enabled to change this setting.
     * Changing this setting does not enable the envelope either.
     */
    void setEnvelope(uint8_t value) noexcept;

    /*!
     * \brief Enables/disables the initial envelope setting
     * \param enable true to enable the setting, false to disable
     */
    void setEnvelopeEnable(bool enable) noexcept;

    /*!
     * \brief equality check for two given instruments
     * \param lhs the first instrument
     * \param rhs the second instrument
     * \return true if the instruments are equal, false otherwise
     *
     * Instruments are equal if
     *  - their envelope settings are the same
     *  - their sequence data are the same
     */
    friend bool operator==(Instrument const& lhs, Instrument const& rhs) noexcept;

    /*!
     * \brief checks if the given instruments are not equal to each other
     * \param lhs the first instrument
     * \param rhs the second instrument
     * \return true if the instruments are not equal, false otherwise
     * \sa operator==(Instrument const& lhs, Instrument const& rhs)
     *
     * Note: this implementation just inverts the return of the == overload
     */
    friend bool operator!=(Instrument const& lhs, Instrument const& rhs) noexcept;

private:

    ChType mChannel;
    bool mEnvelopeEnabled;
    // volume envelope / waveform id
    uint8_t mEnvelope;

    // parameter sequences
    SequenceArray mSequences;


};






}
