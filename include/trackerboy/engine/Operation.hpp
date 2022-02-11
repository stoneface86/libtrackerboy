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

#include "trackerboy/data/TrackRow.hpp"
#include "trackerboy/trackerboy.hpp"

#include <cstdint>
#include <optional>
#include <functional>

namespace trackerboy {


/*!
 * \brief Structure representing a row operation to be executed.
 *
 * Before a TrackRow is played, it is converted to an Operation. The Operation
 * is the parsed version of a TrackRow.
 */
class Operation {

public:

    enum class PatternCommand : uint8_t {
        none,       // do nothing
        next,       // go to the next pattern in the order
        jump        // jump to the given pattern in patternCommandParam
    };

    enum class FrequencyMod : uint8_t {
        none,               // no frequency modulation
        portamento,         // automatic note slide
        pitchSlideUp,       // frequency slides toward a target
        pitchSlideDown,     // frequency slides toward a target
        noteSlideUp,        // frequency slides toward a target note
        noteSlideDown,
        arpeggio            // frequency alternates between 3 notes
    };

    /*!
     * \brief Construct an empty operation, or no-op.
     */
    explicit Operation();

    /*!
     * \brief Construct an operation from the given TrackRow.
     * \param row the row data
     */
    explicit Operation(TrackRow const& row);

    /*!
     * \brief Construct an operation with only the given \a note index.
     * \param note the note index
     *
     * Equivalent to constructing with a TrackRow that only has the note column
     * set.
     */
    explicit Operation(uint8_t note);

    PatternCommand patternCommand() const noexcept;

    uint8_t patternCommandParam() const noexcept;

    uint8_t speed() const noexcept;

    bool halt() const noexcept;

    std::optional<uint8_t> instrument() const noexcept;

    std::optional<uint8_t> note() const noexcept;

    uint8_t delay() const noexcept;

    std::optional<uint8_t> duration() const noexcept;

    std::optional<uint8_t> envelope() const noexcept;

    std::optional<uint8_t> timbre() const noexcept;

    std::optional<uint8_t> panning() const noexcept;

    std::optional<uint8_t> sweep() const noexcept;
    
    uint8_t volume() const noexcept;

    FrequencyMod modulationType() const noexcept;

    uint8_t modulationParam() const noexcept;

    std::optional<uint8_t> vibrato() const noexcept;

    std::optional<uint8_t> vibratoDelay() const noexcept;

    std::optional<uint8_t> tune() const noexcept;

private:

    PatternCommand mPatternCommand;
    uint8_t mPatternCommandParam;
    uint8_t mSpeed;
    uint8_t mVolume;
    bool mHalt;

    std::optional<uint8_t> mNote;
    std::optional<uint8_t> mInstrument;

    uint8_t mDelay;

    std::optional<uint8_t> mDuration;
    std::optional<uint8_t> mEnvelope;
    std::optional<uint8_t> mTimbre;
    std::optional<uint8_t> mPanning;
    std::optional<uint8_t> mSweep;

    // frequency effects
    FrequencyMod mModulationType;
    uint8_t mModulationParam;
    std::optional<uint8_t> mVibrato;
    std::optional<uint8_t> mVibratoDelay;
    std::optional<uint8_t> mTune;
};

}
