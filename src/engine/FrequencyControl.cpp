
#include "trackerboy/engine/FrequencyControl.hpp"
#include "trackerboy/note.hpp"
#include "trackerboy/trackerboy.hpp"

#include <algorithm>
#include <optional>

namespace trackerboy {


FrequencyControl::Context::Context(Instrument const& instrument) :
    arpSequence(instrument.enumerateSequence(Instrument::SEQUENCE_ARP)),
    pitchSequence(instrument.enumerateSequence(Instrument::SEQUENCE_PITCH))
{
}

FrequencyControl::~FrequencyControl() {

}

FrequencyControl::FrequencyControl(uint16_t maxFrequency, uint8_t maxNote) noexcept :
    mMaxFrequency(maxFrequency),
    mMaxNote(maxNote),
    mMod(ModType::none),
    mNote(0),
    mTune(0),
    mFrequency(0),
    mSlideAmount(0),
    mSlideTarget(0),
    mInstrumentPitch(0),
    mChordOffset1(0),
    mChordOffset2(0),
    mChordIndex(0),
    mChord{ 0 },
    mVibratoDelayCounter(0),
    mVibratoCounter(0),
    mVibratoValue(0),
    mVibratoDelay(0),
    mVibratoParam(0)
{
}

uint16_t FrequencyControl::frequency() const noexcept {

    int16_t freq = mFrequency + mTune + mInstrumentPitch;

    // vibrato
    if (mVibratoEnabled && mVibratoDelayCounter == 0) {
        freq += mVibratoValue;
    }

    return static_cast<uint16_t>(std::clamp(
        freq,
        static_cast<int16_t>(0),
        static_cast<int16_t>(mMaxFrequency))
        );

}

void FrequencyControl::reset() noexcept {
    mMod = ModType::none;
    mNote = 0;
    mTune = 0;
    mFrequency = 0;
    mSlideAmount = 0;
    mSlideTarget = 0;
    mChordOffset1 = 0;
    mChordOffset2 = 0;
    mChordIndex = 0;
    mChord.fill(0);
    mVibratoDelayCounter = 0;
    mVibratoCounter = 0;
    mVibratoValue = 0;
    mVibratoDelay = 0;
    mVibratoParam = 0;
}

void FrequencyControl::apply(Operation const& op) noexcept {

    // the arpeggio chord needs to be recalculated when:
    //  * a new note is triggerred and arpeggio is active
    //  * arpeggio effect is activated
    bool updateChord = false;

    bool newNote;
    if (auto note = op.note(); note.has_value()) {
        if (mMod == ModType::noteSlide) {
            // setting a new note cancels a note slide
            mMod = ModType::none;
        }

        mNote = std::min(*note, mMaxNote);
        newNote = true;
    } else {
        newNote = false;
    }
    uint8_t currNote = mNote;
    

    auto const modParam = op.modulationParam();
    switch (auto const modType = op.modulationType(); modType) {
        case Operation::FrequencyMod::arpeggio:
            if (modParam == 0) {
                mMod = ModType::none;
            } else {
                mMod = ModType::arpeggio;
                mChordOffset1 = modParam >> 4;
                mChordOffset2 = modParam & 0xF;
                updateChord = true;
            }
            break;
        case Operation::FrequencyMod::pitchSlideDown:
        case Operation::FrequencyMod::pitchSlideUp:
            if (modParam == 0) {
                mMod = ModType::none;
            } else {
                mMod = ModType::pitchSlide;
                if (modType == Operation::FrequencyMod::pitchSlideUp) {
                    mSlideTarget = mMaxFrequency;
                } else {
                    mSlideTarget = 0;
                }
                mSlideAmount = modParam;
            }
            break;
        case Operation::FrequencyMod::noteSlideDown:
        case Operation::FrequencyMod::noteSlideUp:
            mSlideAmount = 1 + (2 * (modParam & 0xF));
            // upper 4 bits is the # of semitones to slide to
            {
                uint8_t semitones = modParam >> 4;
                uint8_t targetNote = mNote;
                if (modType == Operation::FrequencyMod::noteSlideUp) {
                    targetNote += semitones;
                    if (targetNote > mMaxNote) {
                        targetNote = mMaxNote; // clamp to highest note
                    }
                } else {
                    if (targetNote < semitones) {
                        targetNote = 0; // clamp to the lowest possible note
                    } else {
                        targetNote -= semitones;
                    }
                }
                mMod = ModType::noteSlide;
                mSlideTarget = noteLookup(targetNote);
                // current note becomes the target note (even though it hasn't reached it yet)
                // this allows for bigger slides by chaining multiple note slide effects
                mNote = targetNote;
            }
            break;
        case Operation::FrequencyMod::portamento:
            if (modParam == 0) {
                // turn off portamento
                mMod = ModType::none;
            } else {
                if (mMod != ModType::portamento) {
                    mSlideTarget = mFrequency;
                    mMod = ModType::portamento;
                }
                mSlideAmount = modParam;
            }
            break;
        default:
            // no mod type set, do nothing
            break;
    }

    if (auto vib = op.vibrato(); vib.has_value()) {
        auto param = *vib;
        mVibratoParam = param;
        if (!(param & 0x0F)) {
            // extent is 0, disable vibrato
            mVibratoEnabled = false;
            mVibratoValue = 0;
        } else {
            // extent is non-zero, set vibrato
            mVibratoEnabled = true;
            int8_t newvalue = param & 0xF;
            if (mVibratoValue < 0) {
                mVibratoValue = -newvalue;
            } else {
                mVibratoValue = newvalue;
            }
        }
    }

    if (auto vibDelay = op.vibratoDelay(); vibDelay.has_value()) {
        mVibratoDelay = *vibDelay;
    }

    if (auto tune = op.tune(); tune.has_value()) {
        // tune values have a bias of 0x80, so 0x80 is 0, is in tune
        // 0x81 is +1, frequency is pitch adjusted by 1
        // 0x7F is -1, frequency is pitch adjusted by -1
        mTune = (int8_t)(*tune - 0x80);
    }

    if (newNote) {
        auto freq = noteLookup(currNote);
        if (mMod == ModType::portamento) {
            // automatic portamento, slide to this note
            mSlideTarget = freq;
        } else {
            // otherwise set the current frequency
            if (mMod == ModType::arpeggio) {
                updateChord = true;
            }
            mFrequency = freq;
        }


        if (mVibratoEnabled) {
            mVibratoDelayCounter = mVibratoDelay;
            mVibratoCounter = 0;
            mVibratoValue = mVibratoParam & 0xF;
        }

        mInstrumentPitch = 0;
    }

    if (updateChord) {
        // first note in the chord is always the current note
        mChord[0] = noteLookup(mNote);
        // second note is the upper nibble + the current (clamped to the last possible note)
        mChord[1] = noteLookup(std::min((uint8_t)(mNote + mChordOffset1), mMaxNote));
        // third note is the lower nibble + current (also clamped)
        mChord[2] = noteLookup(std::min((uint8_t)(mNote + mChordOffset2), mMaxNote));
    }


}

void FrequencyControl::useInstrument(Instrument const* instrument) noexcept {
    if (instrument) {
        mContext.emplace(*instrument);
    } else {
        mContext.reset();
    }
}

void FrequencyControl::step() noexcept {

    if (mVibratoEnabled) {

        if (mVibratoDelayCounter) {
            --mVibratoDelayCounter;
        } else {
            if (mVibratoCounter == 0) {
                mVibratoValue = -mVibratoValue;
                mVibratoCounter = mVibratoParam >> 4;
            } else {
                --mVibratoCounter;
            }
        }
    }

    std::optional<uint8_t> arp;
    if (mContext) {
        auto pitch = mContext->pitchSequence.next();
        if (pitch) {
            mInstrumentPitch += (int8_t)*pitch;
        }

        arp = mContext->arpSequence.next();
    }

    if (arp) {
        // absolute
        int8_t offset = (int8_t)*arp;
        int8_t note = (int8_t)std::clamp((int)mNote + offset, 0, (int)mMaxNote);
        mFrequency = noteLookup(note);

        // relative (same as absolute but saves the note)
        //mNote = note;

        // fixed
        //mNote = *arp;
        //mFrequency = noteLookup(mNote);
    } else {
        switch (mMod) {
            case ModType::none:
                break;
            case ModType::portamento:
            case ModType::pitchSlide:
            case ModType::noteSlide:
                if (mFrequency != mSlideTarget) {
                    if (mFrequency < mSlideTarget) {
                        // sliding up
                        mFrequency += mSlideAmount;
                        if (mFrequency > mSlideTarget) {
                            finishSlide();
                        }
                    } else {
                        // sliding down
                        mFrequency -= mSlideAmount;
                        if (mFrequency < mSlideTarget) {
                            finishSlide();
                        }
                    }
                }
                break;
            case ModType::arpeggio:
                mFrequency = mChord[mChordIndex];
                if (++mChordIndex == mChord.size()) {
                    mChordIndex = 0;
                }
                break;
        }
    }



}

void FrequencyControl::finishSlide() noexcept {
    mFrequency = mSlideTarget;
    if (mMod == ModType::noteSlide) {
        // stop sliding once the target note is reached
        mMod = ModType::none;
    }
}


ToneFrequencyControl::ToneFrequencyControl() noexcept :
    FrequencyControl(GB_MAX_FREQUENCY, NOTE_LAST)
{
}

uint16_t ToneFrequencyControl::noteLookup(uint8_t note) {
    return (uint16_t)lookupToneNote(note);
}


NoiseFrequencyControl::NoiseFrequencyControl() noexcept :
    FrequencyControl(NOTE_NOISE_LAST, NOTE_NOISE_LAST)
{
}

uint16_t NoiseFrequencyControl::noteLookup(uint8_t note) {
    return note;
}

uint8_t NoiseFrequencyControl::toNR43(uint16_t frequency) noexcept {
    return (uint8_t)lookupNoiseNote(frequency);

}

}
