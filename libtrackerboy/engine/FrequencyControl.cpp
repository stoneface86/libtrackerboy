
#include "trackerboy/engine/FrequencyControl.hpp"
#include "trackerboy/note.hpp"

#include <algorithm>


#define byteHasZeroNibble(byte) (!(byte & 0xF) || !(byte & 0xF0))

namespace trackerboy {

// The vibrato effect uses a sine waveform. Because sine calculation is expensive
// on the gameboy, we will use a table of precomputed sine waves. To save space, only
// a quarter of the wave will be used, as we can recreate the entire period with just
// a quarter thanks to symmetry.
//
// for example, consider a period of 16 samples, we would need to sample a quarter of the
// period to use as a reference, {a, b, c, d}
// thus the entire period is the sequence:
// {0, d, c, b, a, b, c, d, 0, -d, -c, -b, -a, -b, -c, -d}
//  ^           ^           ^               ^
//  Quarter 1   Quarter 2   Quarter 3       Quarter 4
//
// quarter 2 is our reference period. Note that quarters 3 and 4 are just negated versions of
// quarters 1 and 2, respectively
//
// index | reference index | value
//   0   |  n/a            | 0
//   1   |  3              | d
//   2   |  2              | c
//   3   |  1              | b
//   4   |  0              | a
//   5   |  1              | b
//   6   |  2              | c
//   7   |  3              | d
//   8   |  n/a            | 0
//   9   |  3              | -d
//   A   |  2              | -c
//   B   |  1              | -b
//   C   |  0              | -a
//   D   |  1              | -b
//   E   |  2              | -c
//   F   |  3              | -d
//
// Using the above table, we can calculate any value in the period from an index, using only
// the reference period

// Note:
// extent is the amplitude of the sine waveform, famitracker calls it depth which in that
// case is peak-to-peak (or double the extent)
//
// if you double the extents they should match famitracker's depths for version 0.3.5 and higher
//




const int8_t FrequencyControl::VIBRATO_TABLE[FrequencyControl::VIBRATO_TABLE_EXTENTS][FrequencyControl::VIBRATO_TABLE_LEN] = {
    // this table was generated by genvibrato.py
    // $ genvibrato.py c
    /* extent:   1 */ { 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00 },
    /* extent:   2 */ { 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00 },
    /* extent:   3 */ { 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x02, 0x02, 0x02, 0x02, 0x02, 0x01, 0x01, 0x01, 0x01, 0x00 },
    /* extent:   4 */ { 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x03, 0x03, 0x03, 0x03, 0x02, 0x02, 0x02, 0x01, 0x01, 0x00 },
    /* extent:   5 */ { 0x05, 0x05, 0x05, 0x05, 0x05, 0x04, 0x04, 0x04, 0x04, 0x03, 0x03, 0x02, 0x02, 0x01, 0x01, 0x00 },
    /* extent:   7 */ { 0x07, 0x07, 0x07, 0x07, 0x06, 0x06, 0x06, 0x05, 0x05, 0x04, 0x04, 0x03, 0x03, 0x02, 0x01, 0x01 },
    /* extent:  10 */ { 0x0A, 0x0A, 0x0A, 0x0A, 0x09, 0x09, 0x08, 0x08, 0x07, 0x06, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01 },
    /* extent:  12 */ { 0x0C, 0x0C, 0x0C, 0x0B, 0x0B, 0x0B, 0x0A, 0x09, 0x08, 0x08, 0x07, 0x06, 0x05, 0x03, 0x02, 0x01 },
    /* extent:  14 */ { 0x0E, 0x0E, 0x0E, 0x0D, 0x0D, 0x0C, 0x0C, 0x0B, 0x0A, 0x09, 0x08, 0x07, 0x05, 0x04, 0x03, 0x01 },
    /* extent:  17 */ { 0x11, 0x11, 0x11, 0x10, 0x10, 0x0F, 0x0E, 0x0D, 0x0C, 0x0B, 0x09, 0x08, 0x07, 0x05, 0x03, 0x02 },
    /* extent:  22 */ { 0x16, 0x16, 0x16, 0x15, 0x14, 0x13, 0x12, 0x11, 0x10, 0x0E, 0x0C, 0x0A, 0x08, 0x06, 0x04, 0x02 },
    /* extent:  30 */ { 0x1E, 0x1E, 0x1D, 0x1D, 0x1C, 0x1A, 0x19, 0x17, 0x15, 0x13, 0x11, 0x0E, 0x0B, 0x09, 0x06, 0x03 },
    /* extent:  44 */ { 0x2C, 0x2C, 0x2B, 0x2A, 0x29, 0x27, 0x25, 0x22, 0x1F, 0x1C, 0x18, 0x15, 0x11, 0x0D, 0x09, 0x04 },
    /* extent:  64 */ { 0x40, 0x40, 0x3F, 0x3D, 0x3B, 0x38, 0x35, 0x31, 0x2D, 0x29, 0x24, 0x1E, 0x18, 0x13, 0x0C, 0x06 },
    /* extent:  96 */ { 0x60, 0x60, 0x5E, 0x5C, 0x59, 0x55, 0x50, 0x4A, 0x44, 0x3D, 0x35, 0x2D, 0x25, 0x1C, 0x13, 0x09 },
    /* extent: 127 */ { 0x7F, 0x7E, 0x7D, 0x7A, 0x75, 0x70, 0x6A, 0x62, 0x5A, 0x51, 0x47, 0x3C, 0x31, 0x25, 0x19, 0x0C }
};


FrequencyControl::FrequencyControl() noexcept :
    mFlags(0),
    mEffect(Effect::none),
    mNote(0),
    mTune(0),
    mFrequency(0),
    mSlideAmount(0),
    mSlideTarget(0),
    mSlideNote(0),
    mChordParam(0),
    mChordIndex(0),
    mChord{ 0 },
    mVibratoCounter(0),
    mVibratoIndex(0),
    mVibratoSpeed(0),
    mVibratoTable(VIBRATO_TABLE[0])
{
}

uint16_t FrequencyControl::frequency() const noexcept {

    int16_t freq = mFrequency + mTune;

    // vibrato
    if (!!(mFlags & FLAG_VIBRATO)) {
        freq += mVibratoCounter;
    }

    return static_cast<uint16_t>(std::clamp(
        freq, 
        static_cast<int16_t>(0),
        static_cast<int16_t>(Gbs::MAX_FREQUENCY))
    );

}

void FrequencyControl::setPitchSlide(SlideDirection dir, uint8_t param) noexcept {
    mFlags &= ~FLAG_PORTAMENTO;
    if (param == 0) {
        mEffect = Effect::none;
    } else {
        mEffect = Effect::slide;
        mSlideAmount = param;
        setTarget(dir == SlideDirection::up ? Gbs::MAX_FREQUENCY : 0);
    }
    
}

void FrequencyControl::setNoteSlide(SlideDirection dir, uint8_t param) noexcept {

    // turn off arpeggio and portamento
    mFlags &= ~FLAG_PORTAMENTO;

    // enable slide
    mEffect = Effect::slide;
    // lower 4 bits of param is the slide amount
    // the speed is determined by the formula 2x + 1
    // (1 to 31 pitch units/frame)
    mSlideAmount = 1 + (2 * (param & 0xF));
    // upper 4 bits is the # of semitones to slide to
    uint8_t semitones = param >> 4;
    uint8_t targetNote = mNote;
    
    if (dir == SlideDirection::up) {
        targetNote += semitones;
        if (targetNote > NOTE_LAST) {
            targetNote = NOTE_LAST; // clamp to highest note
        }
    } else {
        if (targetNote < semitones) {
            targetNote = 0; // clamp to the lowest possible note
        } else {
            targetNote -= semitones;
        }
    }

    mSlideNote = targetNote;
    mFlags |= FLAG_NOTE_SLIDE_SET;

}

void FrequencyControl::setVibrato(uint8_t param) noexcept {
    if (!(param & 0xF0)) {
        // speed is 0, disable vibrato
        mFlags &= ~FLAG_VIBRATO;
        mVibratoIndex = 0;
    } else {
        // both nibbles are non-zero, set vibrato
        mFlags |= FLAG_VIBRATO;
        mVibratoSpeed = param >> 4;
        mVibratoTable = VIBRATO_TABLE[param & 0xF];
    }
}

void FrequencyControl::setArpeggio(uint8_t param) noexcept {
    // disable slide (if set)
    mFlags &= ~FLAG_PORTAMENTO;

    if (param == 0) {
        mEffect = Effect::none;
        // reset note frequency
        mFlags |= FLAG_NOTE_SET;
    } else {    
        // enable arpeggio
        mEffect = Effect::arpeggio;

        mChordIndex = 0;
        mChordParam = param;
        setChord();
        
    }
}

void FrequencyControl::setPortamento(uint8_t param) noexcept {
    
    if (param == 0) {
        // turn off pitch slide w/ portamento
        mEffect = Effect::none;
        mFlags &= ~FLAG_PORTAMENTO;
    } else {
        // turn on pitch slide w/ portamento
        mEffect = Effect::slide;
        mFlags |= FLAG_PORTAMENTO;
        mSlideAmount = param;
    }
}

void FrequencyControl::setNote(uint8_t note) noexcept {
    // ignore special note and illegal note indices
    if (note <= NOTE_LAST) {
        mFlags |= FLAG_NOTE_SET;
        mNote = note;
    }
}

void FrequencyControl::setTune(uint8_t param) noexcept {
    // tune values have a bias of 0x80, so 0x80 is 0, is in tune
    // 0x81 is +1, frequency is pitch adjusted by 1
    // 0x7F is -1, frequency is pitch adjusted by -1
    mTune = static_cast<int8_t>(param - 0x80);
}

void FrequencyControl::step() noexcept {

    if (!!(mFlags & FLAG_NOTE_SET)) {
        mChordIndex = 0;
        uint16_t noteFreq = NOTE_FREQ_TABLE[mNote];
        if (mEffect == Effect::arpeggio) {
            setChord();
        } else if (!!(mFlags & FLAG_PORTAMENTO) && !!(mFlags & FLAG_FIRST)) {
            setTarget(noteFreq);
        } else {
            mFrequency = noteFreq;
        }
        mFlags &= ~FLAG_NOTE_SET;
        mFlags |= FLAG_FIRST;
    }

    if (!!(mFlags & FLAG_NOTE_SLIDE_SET)) {
        setTarget(NOTE_FREQ_TABLE[mSlideNote]);
        mNote = mSlideNote;
        mFlags &= ~FLAG_NOTE_SLIDE_SET;
    }

    if (!!(mFlags & FLAG_VIBRATO)) {
        uint8_t qindex = mVibratoIndex & VIBRATO_HALF_MASK;
        if (qindex == 0) {
            mVibratoCounter = 0;
        } else {
            if (qindex >= VIBRATO_TABLE_LEN) {
                // quadrant II/IV
                mVibratoCounter = mVibratoTable[qindex - VIBRATO_TABLE_LEN];
            } else {
                // quadrant I/III
                mVibratoCounter = mVibratoTable[VIBRATO_TABLE_LEN - qindex];
            }

            if (mVibratoIndex >= VIBRATO_PERIOD_SIZE / 2) {
                // second half of the period is negative
                mVibratoCounter = -mVibratoCounter;
            }
        }

        
        // add the speed to the index
        mVibratoIndex = (mVibratoIndex + mVibratoSpeed) & VIBRATO_MASK;
    }

    switch (mEffect) {
        case Effect::none:
            break;
        case Effect::slide:
            if (!!(mFlags & FLAG_SLIDING)) {
                if (mFrequency < mSlideTarget) {
                    // sliding up
                    mFrequency += mSlideAmount;
                    if (mFrequency > mSlideTarget) {
                        mFrequency = mSlideTarget;
                        mFlags &= ~FLAG_SLIDING;
                    }
                } else {
                    // sliding down
                    mFrequency -= mSlideAmount;
                    if (mFrequency < mSlideTarget) {
                        mFrequency = mSlideTarget;
                        mFlags &= ~FLAG_SLIDING;
                    }
                }
            }
            break;
        case Effect::arpeggio:
            mFrequency = mChord[mChordIndex];
            if (++mChordIndex == CHORD_LEN) {
                mChordIndex = 0;
            }
            break;
    }



}

void FrequencyControl::setTarget(uint16_t freq) noexcept {
    mSlideTarget = freq;
    if (mFrequency != mSlideTarget) {
        mFlags |= FLAG_SLIDING;
    }
}

void FrequencyControl::setChord() noexcept {
    // first note in the chord is always the current note
    mChord[0] = NOTE_FREQ_TABLE[mNote];
    // second note is the upper nibble + the current (clamped to the last possible note)
    mChord[1] = NOTE_FREQ_TABLE[std::min(mNote + (mChordParam >> 4), static_cast<int>(NOTE_LAST))];
    // third note is the lower nibble + current (also clamped)
    mChord[2] = NOTE_FREQ_TABLE[std::min(mNote + (mChordParam & 0xF), static_cast<int>(NOTE_LAST))];
}


}
