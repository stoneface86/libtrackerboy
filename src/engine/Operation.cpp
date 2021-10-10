
#include "trackerboy/engine/Operation.hpp"
#include "trackerboy/note.hpp"

#include <algorithm>
#include <numeric>

#define TU OperationTU

namespace trackerboy {

Operation::Operation() :
    mPatternCommand(PatternCommand::none),
    mPatternCommandParam(0),
    mSpeed(0),
    mHalt(false),
    mNote(),
    mInstrument(),
    mDelay(0),
    mDuration(),
    mEnvelope(),
    mTimbre(),
    mPanning(),
    mSweep(),
    mModulationType(FrequencyMod::none),
    mModulationParam(0),
    mVibrato(),
    mVibratoDelay(),
    mTune()
{
}


Operation::Operation(TrackRow const& row) :
    Operation()
{

    // note column
    mNote = row.queryNote();
    if (mNote && *mNote == NOTE_CUT) {
        // NOTE_CUT behaves exactly the same as the S00 effect
        // this also makes the Sxx effect have higher priority unless we process the note after effects
        // --  .. ... ... ... same as: ... .. S00 ... ...
        // --  .. S03 ... ... => the row will cut in 3 frames
        mNote.reset();
        mDuration = 0;
    }

    // instrument column
    mInstrument = row.queryInstrument();

    // effects
    for (size_t i = 0; i != TrackRow::MAX_EFFECTS; ++i) {
        auto effect = row.queryEffect(i);
        if (effect) {
            auto param = effect->param;
            switch (effect->type) {
                case trackerboy::EffectType::patternGoto:
                    mPatternCommand = PatternCommand::jump;
                    mPatternCommandParam = param;
                    break;
                case trackerboy::EffectType::patternHalt:
                    mHalt = true;
                    break;
                case trackerboy::EffectType::patternSkip:
                    mPatternCommand = PatternCommand::next;
                    mPatternCommandParam = param;
                    break;
                case trackerboy::EffectType::setTempo:
                    if (param >= SPEED_MIN && param <= SPEED_MAX) {
                        mSpeed = param;
                    }
                    break;
                case trackerboy::EffectType::sfx:
                    // TBD
                    break;
                case trackerboy::EffectType::setEnvelope:
                    mEnvelope = param;
                    break;
                case trackerboy::EffectType::setTimbre:
                    mTimbre = std::clamp(param, (uint8_t)0, (uint8_t)3);
                    break;
                case trackerboy::EffectType::setPanning:
                    mPanning = std::clamp(param, (uint8_t)0, (uint8_t)3);
                    break;
                case trackerboy::EffectType::setSweep:
                    mSweep = param;
                    break;
                case trackerboy::EffectType::delayedCut:
                    mDuration = param;
                    break;
                case trackerboy::EffectType::delayedNote:
                    mDelay = param;
                    break;
                case trackerboy::EffectType::lock:
                    // TBD
                    break;
                case trackerboy::EffectType::arpeggio:
                    mModulationType = FrequencyMod::arpeggio;
                    mModulationParam = param;
                    break;
                case trackerboy::EffectType::pitchUp:
                    mModulationType = FrequencyMod::pitchSlideUp;
                    mModulationParam = param;
                    break;
                case trackerboy::EffectType::pitchDown:
                    mModulationType = FrequencyMod::pitchSlideDown;
                    mModulationParam = param;
                    break;
                case trackerboy::EffectType::autoPortamento:
                    mModulationType = FrequencyMod::portamento;
                    mModulationParam = param;
                    break;
                case trackerboy::EffectType::vibrato:
                    mVibrato = param;
                    break;
                case trackerboy::EffectType::vibratoDelay:
                    mVibratoDelay = param;
                    break;
                case trackerboy::EffectType::tuning:
                    mTune = param;
                    break;
                case trackerboy::EffectType::noteSlideUp:
                    mModulationType = FrequencyMod::noteSlideUp;
                    mModulationParam = param;
                    break;
                case trackerboy::EffectType::noteSlideDown:
                    mModulationType = FrequencyMod::noteSlideDown;
                    mModulationParam = param;
                    break;
                default:
                    // unknown effect, possibly defined in a newer version of trackerboy
                    break;
            }
        }
    }

}

Operation::Operation(uint8_t note) :
    Operation()
{
    if (note == NOTE_CUT) {
        mDuration = 1;
    } else {
        mNote = note;
    }
}

Operation::PatternCommand Operation::patternCommand() const noexcept {
    return mPatternCommand;
}

uint8_t Operation::patternCommandParam() const noexcept {
    return mPatternCommandParam;
}

uint8_t Operation::speed() const noexcept {
    return mSpeed;
}

bool Operation::halt() const noexcept {
    return mHalt;
}

std::optional<uint8_t> Operation::instrument() const noexcept {
    return mInstrument;
}

std::optional<uint8_t> Operation::note() const noexcept {
    return mNote;
}

uint8_t Operation::delay() const noexcept {
    return mDelay;
}

std::optional<uint8_t> Operation::duration() const noexcept {
    return mDuration;
}

std::optional<uint8_t> Operation::envelope() const noexcept {
    return mEnvelope;
}

std::optional<uint8_t> Operation::timbre() const noexcept {
    return mTimbre;
}

std::optional<uint8_t> Operation::panning() const noexcept {
    return mPanning;
}

Operation::FrequencyMod Operation::modulationType() const noexcept {
    return mModulationType;
}

uint8_t Operation::modulationParam() const noexcept {
    return mModulationParam;
}

std::optional<uint8_t> Operation::vibrato() const noexcept {
    return mVibrato;
}

std::optional<uint8_t> Operation::vibratoDelay() const noexcept {
    return mVibratoDelay;
}

std::optional<uint8_t> Operation::tune() const noexcept {
    return mTune;
}

}
