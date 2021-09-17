
#include "internal/apu.hpp"
#include "trackerboy/trackerboy.hpp"

#include <algorithm>
#include <cassert>

namespace trackerboy {

namespace apu {

#define TU apuTU
namespace TU {

}

// ---------------------------------------------------------------------- Timer

Timer::Timer(uint32_t period) :
    mTimer(period),
    mPeriod(period)
{
}

uint32_t Timer::timer() const noexcept {
    return mTimer;
}

bool Timer::stepTimer(uint32_t cycles) {
    // if this assertion fails then we have missed a clock from the frequency timer!
    assert(mTimer >= cycles);

    mTimer -= cycles;
    if (mTimer == 0) {
        mTimer = mPeriod;
        return true;
    } else {
        return false;
    }
}

// ---------------------------------------------------------------- ChannelBase

ChannelBase::ChannelBase(uint32_t defaultPeriod, unsigned lengthCounterMax) noexcept :
    Timer(defaultPeriod),
    mFrequency(0),
    mOutput(0),
    mDacOn(false),
    mLengthCounter(0),
    mLengthEnabled(false),
    mDisabled(true),
    mLengthCounterMax(lengthCounterMax),
    mDefaultPeriod(defaultPeriod)
{
}

bool ChannelBase::dacOn() const noexcept {
    return mDacOn;
}

bool ChannelBase::lengthEnabled() const noexcept {
    return mLengthEnabled;
}

void ChannelBase::disable() noexcept {
    mDisabled = true;
}

uint16_t ChannelBase::frequency() const noexcept {
    return mFrequency;
}

void ChannelBase::setDacEnable(bool enabled) noexcept {
    mDacOn = enabled;
    if (!enabled) {
        disable();
    }
}

void ChannelBase::stepLengthCounter() noexcept {
    if (mLengthEnabled) {
        if (mLengthCounter == 0) {
            disable();
        } else {
            --mLengthCounter;
        }
    }
}

int8_t ChannelBase::output() const noexcept {
    // might want to optimize this by making mDacOn a mask
    return mDacOn ? mOutput : 0;
}

void ChannelBase::writeLengthCounter(uint8_t value) noexcept {
    mLengthCounter = value;
}

void ChannelBase::reset() noexcept {
    mDacOn = false;
    mDisabled = true;
    mFrequency = 0;
    mLengthCounter = 0;
    mLengthEnabled = false;
    mPeriod = mDefaultPeriod;
    mTimer = mPeriod;
}

void ChannelBase::restart() noexcept {
    mTimer = mPeriod; // reload frequency timer with period
    if (mLengthCounter == 0) {
        mLengthCounter = mLengthCounterMax;
    }
    mDisabled = !mDacOn;
}

void ChannelBase::setLengthCounterEnable(bool enable) {
    mLengthEnabled = enable;
}

// ------------------------------------------------------------- EnvChannelBase

EnvChannelBase::EnvChannelBase(uint32_t defaultPeriod, unsigned lengthCounterMax) noexcept :
    ChannelBase(defaultPeriod, lengthCounterMax),
    mEnvelopeRegister(0),
    mEnvelopeCounter(0),
    mEnvelopePeriod(0),
    mEnvelopeAmplify(false),
    mVolume(0)
{
}

uint8_t EnvChannelBase::readEnvelope() const noexcept {
    return mEnvelopeRegister;
}

void EnvChannelBase::writeEnvelope(uint8_t value) noexcept {
    setDacEnable(!!(value & 0xF8));
    mEnvelopeRegister = value;
}

void EnvChannelBase::restart() noexcept {
    mEnvelopeCounter = 0;
    mEnvelopePeriod = mEnvelopeRegister & 0x7;
    mEnvelopeAmplify = !!(mEnvelopeRegister & 0x8);
    mVolume = mEnvelopeRegister >> 4;
    ChannelBase::restart();
}

void EnvChannelBase::stepEnvelope() noexcept {
    if (mEnvelopePeriod) {
        // do nothing if period == 0
        if (++mEnvelopeCounter == mEnvelopePeriod) {
            mEnvelopeCounter = 0;
            if (mEnvelopeAmplify) {
                if (mVolume < 0xF) {
                    ++mVolume;
                }
            } else {
                if (mVolume > 0x0) {
                    --mVolume;
                }
            }
        }
    }
}

void EnvChannelBase::reset() noexcept {
    ChannelBase::reset();

    mEnvelopeRegister = 0;
    mEnvelopeCounter = 0;
    mEnvelopePeriod = 0;
    mEnvelopeAmplify = false;
    mVolume = 0;
}

// --------------------------------------------------------------- PulseChannel


namespace TU {
// multiplier for frequency calculation
// 64 Hz - 131.072 KHz
static constexpr unsigned PULSE_MULTIPLIER = 4;

//                    STEP: 76543210
// Bits 24-31 - 75%   Duty: 01111110 (0x7E) _------_
// Bits 16-23 - 50%   Duty: 11100001 (0xE1) -____---
// Bits  8-15 - 25%   Duty: 10000001 (0x81) -______-
// Bits  0-7  - 12.5% Duty: 10000000 (0x80) _______-

static constexpr uint32_t DUTY_MASK = 0x7EE18180;


static constexpr uint32_t PULSE_DEFAULT_PERIOD = (2048 - 0) * PULSE_MULTIPLIER;

#define dutyWaveform(duty) ((TU::DUTY_MASK >> (duty << 3)) & 0xFF)

}

PulseChannel::PulseChannel() noexcept :
    EnvChannelBase(TU::PULSE_DEFAULT_PERIOD, 64),
    mDuty(3),
    mDutyWaveform(dutyWaveform(3)),
    mDutyCounter(0)
{
}

uint8_t PulseChannel::readDuty() const noexcept {
    return mDuty << 6;
}

void PulseChannel::reset() noexcept {
    EnvChannelBase::reset();
    mDutyCounter = 0;
    mFrequency = 0;
    writeDuty(3);
    restart();
}

void PulseChannel::writeDuty(uint8_t duty) noexcept {
    mDuty = duty;
    mDutyWaveform = dutyWaveform(duty);
}

void PulseChannel::stepOscillator() noexcept {
    // this implementation uses bit shifting instead of a lookup table

    // increment duty counter
    mDutyCounter = (mDutyCounter + 1) & 0x7;
    mOutput = -((mDutyWaveform >> mDutyCounter) & 1) & mVolume;


}

void PulseChannel::setPeriod() noexcept {
    mPeriod = (2048 - mFrequency) * TU::PULSE_MULTIPLIER;
}

#undef dutyWaveform

// ---------------------------------------------------------- SweepPulseChannel

SweepPulseChannel::SweepPulseChannel() noexcept :
    PulseChannel(),
    mSweepSubtraction(false),
    mSweepTime(0),
    mSweepShift(0),
    mSweepCounter(0),
    mSweepRegister(0),
    mShadow(0)
{
}

uint8_t SweepPulseChannel::readSweep() const noexcept {
    return mSweepRegister;
}

void SweepPulseChannel::reset() noexcept {
    PulseChannel::reset();
    mSweepRegister = 0;
    restart();
}

void SweepPulseChannel::restart() noexcept {
    PulseChannel::restart();
    mSweepCounter = 0;
    mSweepShift = mSweepRegister & 0x7;
    mSweepSubtraction = !!((mSweepRegister >> 3) & 1);
    mSweepTime = (mSweepRegister >> 4) & 0x7;
    mShadow = mFrequency;
}

void SweepPulseChannel::writeSweep(uint8_t reg) noexcept {
    mSweepRegister = reg & 0x7F;
}

void SweepPulseChannel::stepSweep() noexcept {
    if (mSweepTime) {
        if (++mSweepCounter >= mSweepTime) {
            mSweepCounter = 0;
            if (mSweepShift) {
                int16_t sweepfreq = mShadow >> mSweepShift;
                if (mSweepSubtraction) {
                    sweepfreq = mShadow - sweepfreq;
                    if (sweepfreq < 0) {
                        return; // no change
                    }
                } else {
                    sweepfreq = mShadow + sweepfreq;
                    if (sweepfreq > GB_MAX_FREQUENCY) {
                        // sweep will overflow, disable the channel
                        disable();
                        return;
                    }
                }
                // no overflow/underflow
                // write-back the shadow register to CH1's frequency register
                mFrequency = static_cast<uint16_t>(sweepfreq);
                setPeriod();
                mShadow = sweepfreq;
            }
        }
    }
}

// ---------------------------------------------------------------- WaveChannel

namespace TU {
    // multiplier for frequency calculation
    // 32 Hz - 65.536 KHz
    static constexpr unsigned WAVE_MULTIPLIER = 2;
}

WaveChannel::WaveChannel() noexcept :
    ChannelBase((2048 - 0) * TU::WAVE_MULTIPLIER, 0),
    mVolumeShift(0),
    mWaveIndex(0),
    mSampleBuffer(0),
    mWaveram{0}
{
}

uint8_t* WaveChannel::waveram() noexcept {
    return mWaveram.data();
}

uint8_t WaveChannel::readVolume() const noexcept {
    static uint8_t const shiftToNr32[] = {
        0x20, // mVolumeShift = 0
        0x40, // mVolumeShift = 1
        0x60, // mVolumeShift = 2
        0x00, // mVolumeShift = 3 (NOT USABLE)
        0x00  // mVolumeShift = 4
    };
    return shiftToNr32[mVolumeShift];
}

void WaveChannel::reset() noexcept {
    ChannelBase::reset();
    mVolumeShift = 0;
    mSampleBuffer = 0;
    mWaveram.fill((uint8_t)0);
    restart();
}

void WaveChannel::restart() noexcept {
    ChannelBase::restart();
    // wave position is reset to 0, but the sample buffer remains unchanged
    mWaveIndex = 0;
}

void WaveChannel::writeVolume(uint8_t volume) noexcept {
    static uint8_t const nr32ToShift[] = {
        4, // nr32 = 0x00 (Mute)
        0, // nr32 = 0x20 (100%)
        1, // nr32 = 0x40 ( 50%)
        2, // nr32 = 0x60 ( 25%)
    };

    // convert nr32 register to a shift amount
    // shift = 0 : sample / 1  = 100%
    // shift = 1 : sample / 2  =  50%
    // shift = 2 : sample / 4  =  25%
    // shift = 4 : sample / 16 =   0%
    auto volumeIndex = (volume >> 5) & 3;
    mVolumeShift = nr32ToShift[volumeIndex];
    setOutput();
}

void WaveChannel::stepOscillator() noexcept {

    mWaveIndex = (mWaveIndex + 1) & 0x1F;
    mSampleBuffer = mWaveram[mWaveIndex >> 1];
    if (mWaveIndex & 1) {
        // odd number, low nibble
        mSampleBuffer &= 0xF;
    } else {
        // even number, high nibble
        mSampleBuffer >>= 4;
    }


    setOutput();

}

void WaveChannel::setPeriod() noexcept {
    mPeriod = (2048 - mFrequency) * TU::WAVE_MULTIPLIER;
}

void WaveChannel::setOutput() {
    mOutput = mSampleBuffer >> mVolumeShift;
}

// --------------------------------------------------------------- NoiseChannel

namespace TU {

constexpr uint16_t LFSR_INIT = 0x7FFF;

}

NoiseChannel::NoiseChannel() noexcept :
    EnvChannelBase(8, 64),
    mValidScf(true),
    mHalfWidth(false),
    mLfsr(TU::LFSR_INIT)
{
}

uint8_t NoiseChannel::readNoise() const noexcept {
    return static_cast<uint8_t>(mFrequency);
}

void NoiseChannel::reset() noexcept {
    EnvChannelBase::reset();
    mValidScf = true;
    mLfsr = TU::LFSR_INIT;
}

void NoiseChannel::restart() noexcept {
    EnvChannelBase::restart();
    mLfsr = TU::LFSR_INIT;
    // bit 0 inverted of LFSR_INIT is 0
    mOutput = 0;
}

void NoiseChannel::stepOscillator() noexcept {

    if (mValidScf) {

        // xor bits 1 and 0 of the lfsr
        uint8_t result = (mLfsr & 0x1) ^ ((mLfsr >> 1) & 0x1);
        // shift the register
        mLfsr >>= 1;
        // set the resulting xor to bit 15 (feedback)
        mLfsr |= result << 14;
        if (mHalfWidth) {
            // 7-bit lfsr, set bit 7 with the result
            mLfsr &= ~0x40; // reset bit 7
            mLfsr |= result << 6; // set bit 7 result
        }

        mOutput = -((~mLfsr) & 1) & mVolume;
    }

}

void NoiseChannel::setPeriod() noexcept {
    // drf = "dividing ratio frequency", divisor, etc
    uint8_t drf = mFrequency & 0x7;
    if (drf == 0) {
        drf = 8;
    } else {
        drf *= 16;
    }
    mHalfWidth = !!((mFrequency >> 3) & 1);
    // scf = "shift clock frequency"
    auto scf = mFrequency >> 4;
    mValidScf = scf < 0xE; // obscure behavior: a scf of 14 or 15 results in the channel receiving no clocks
    mPeriod = drf << scf;
}

// -------------------------------------------------------------------- Channel

// using CRTP to avoid virtual function calls

template <class T>
void Channel<T>::writeFrequencyLsb(uint8_t value) {
    this->mFrequency = (this->mFrequency & 0xFF00) | value;
    T::setPeriod();
}

template <class T>
void Channel<T>::writeFrequencyMsb(uint8_t value) {
    this->mFrequency = (this->mFrequency & 0x00FF) | ((value & 0x7) << 8);
    T::setPeriod();
    T::setLengthCounterEnable(!!(value & 0x40));

    if (!!(value & 0x80)) {
        T::restart();
    }
}

template <class T>
void Channel<T>::step() {
    if (T::stepTimer(STEP_UNIT)) {
        T::stepOscillator();
    }
}

template class Channel<PulseChannel>;
template class Channel<SweepPulseChannel>;
template class Channel<WaveChannel>;
template class Channel<NoiseChannel>;


// ------------------------------------------------------------------ Sequencer


// A step occurs every 8192 cycles (4194304 Hz / 8192 = 512 Hz)
//
// Step:                 | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
// --------------------------+---+---+---+---+---+---+---+-------------------
// Len. counter (256 Hz) | x       x       x       x
// Sweep        (128 Hz) |         x               x
// envelope     ( 64 Hz) |                             x
//

Sequencer::Trigger const Sequencer::TRIGGER_SEQUENCE[] = {

    {1,     CYCLES_PER_STEP * 2,    TriggerType::lc},

    {2,     CYCLES_PER_STEP * 2,    TriggerType::lcSweep},

    {3,     CYCLES_PER_STEP,        TriggerType::lc},

    // step 6 trigger, next trigger: 7
    {4,     CYCLES_PER_STEP,        TriggerType::lcSweep},

    // step 7 trigger, next trigger: 0
    {0,     CYCLES_PER_STEP * 2,    TriggerType::env}
};

Sequencer::Sequencer(ChannelFile &cf) noexcept :
    Timer(DEFAULT_PERIOD),
    mCf(cf),
    mTriggerIndex(0)
{
}

void Sequencer::reset() noexcept {
    mPeriod = mTimer = DEFAULT_PERIOD;
    mTriggerIndex = 0;
}

void Sequencer::step() noexcept {

    if (stepTimer(STEP_UNIT)) {
        Trigger const &trigger = TRIGGER_SEQUENCE[mTriggerIndex];
        switch (trigger.type) {
            case TriggerType::lcSweep:
                mCf.ch1.stepSweep();
                [[fallthrough]];
            case TriggerType::lc:
                mCf.ch1.stepLengthCounter();
                mCf.ch2.stepLengthCounter();
                mCf.ch3.stepLengthCounter();
                mCf.ch4.stepLengthCounter();
                break;
            case TriggerType::env:
                mCf.ch1.stepEnvelope();
                mCf.ch2.stepEnvelope();
                mCf.ch4.stepEnvelope();
                break;
        }
        mPeriod = trigger.nextPeriod;
        mTriggerIndex = trigger.nextIndex;
    }

}


#undef TU

}

}
