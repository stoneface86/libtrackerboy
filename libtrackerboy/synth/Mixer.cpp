
#include "trackerboy/synth.hpp"

// each channel has a maximum volume of 0.2, so maximum volume of all channels is 0.8
#define VOL_MULTIPLIER 0.2f

namespace trackerboy {

static const float VOLUME_TABLE[8] = {
    0.125f,
    0.25f,
    0.375f,
    0.5f,
    0.625f,
    0.75f,
    0.875f,
    1.0f,
};


Mixer::Mixer() :
    s01enable(DEFAULT_TERM_ENABLE),
    s02enable(DEFAULT_TERM_ENABLE),
    s01vol(DEFAULT_TERM_VOLUME),
    s02vol(DEFAULT_TERM_VOLUME),
    outputStat(all_off)
{
}

void Mixer::getOutput(float in1, float in2, float in3, float in4, float &outLeft, float &outRight) {
    float left = 0.0f, right = 0.0f;
    if (s01enable) {
        if (outputStat & left1) {
            left += in1 * VOL_MULTIPLIER;
        }
        if (outputStat & left2) {
            left += in2 * VOL_MULTIPLIER;
        }
        if (outputStat & left3) {
            left += in3 * VOL_MULTIPLIER;
        }
        if (outputStat & left4) {
            left += in4 * VOL_MULTIPLIER;
        }
    }
    if (s02enable) {
        if (outputStat & right1) {
            right += in1 * VOL_MULTIPLIER;
        }
        if (outputStat & right2) {
            right += in2 * VOL_MULTIPLIER;
        }
        if (outputStat & right3) {
            right += in3 * VOL_MULTIPLIER;
        }
        if (outputStat & right4) {
            right += in4 * VOL_MULTIPLIER;
        }
    }
    // TODO: cache these table lookups in a member variable
    outLeft = left * VOLUME_TABLE[s01vol];
    outRight = right * VOLUME_TABLE[s02vol];
}

void Mixer::setEnable(OutputFlags flags) {
    outputStat = flags;
}

void Mixer::setEnable(ChType ch, Terminal term, bool enabled) {
    uint8_t flag = 0;
    if (term & term_left) {
        flag = 1 << static_cast<uint8_t>(ch);
    }

    if (term & term_right) {
        flag |= flag << 4;
    }

    if (enabled) {
        outputStat |= flag;
    } else {
        outputStat &= ~flag;
    }
}

void Mixer::setTerminalEnable(Terminal term, bool enabled) {
    if (term & term_left) {
        s01enable = enabled;
    }

    if (term & term_right) {
        s02enable = enabled;
    }
}

void Mixer::setTerminalVolume(Terminal term, uint8_t volume) {
    if (volume > MAX_TERM_VOLUME) {
        volume = MAX_TERM_VOLUME;
    }

    if (term & term_left) {
        s01vol = volume;
    }

    if (term & term_right) {
        s02vol = volume;
    }
}

}