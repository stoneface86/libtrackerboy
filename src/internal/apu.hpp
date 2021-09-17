
#pragma once

#include <array>
#include <cstdint>

namespace trackerboy {

namespace apu {

using GbSample = int8_t;

// the number of clocks (T-states) a step does
constexpr uint32_t STEP_UNIT = 2;


// reset functions are to be called during a hardware reset
// restart functions should be called during channel retrigger/restart


//
// Base class for all internal components in the APU.
//
class Timer {

public:

    //
    // Returns the frequency timer, or the number of cycles needed to complete a period.
    //
    uint32_t timer() const noexcept;

protected:

    Timer(uint32_t period);

    //
    // step the timer the given number of cycles. If the timer is now 0,
    // true is returned and the timer is reloaded with the period
    //
    bool stepTimer(uint32_t cycles);

    uint32_t mTimer;
    uint32_t mPeriod;


};

class ChannelBase : public Timer {

public:

    bool dacOn() const noexcept;

    bool lengthEnabled() const noexcept;

    void reset() noexcept;

    void restart() noexcept;

    void setDacEnable(bool enabled) noexcept;

    void stepLengthCounter() noexcept;

    int8_t output() const noexcept;

    void writeLengthCounter(uint8_t value) noexcept;

protected:

    ChannelBase(uint32_t defaultPeriod, unsigned lengthCounterMax) noexcept;

    void disable() noexcept;

    void setLengthCounterEnable(bool enable);

    uint16_t frequency() const noexcept;

    uint16_t mFrequency; // 0-2047 (for noise channel only 8 bits are used)

    // PCM value going into the DAC (0 to F)
    int8_t mOutput;


    bool mDacOn;

private:


    unsigned mLengthCounter;
    bool mLengthEnabled;
    bool mDisabled;

    unsigned const mLengthCounterMax;
    uint32_t const mDefaultPeriod;

};

// adds a volume envelope to the base class
class EnvChannelBase : public ChannelBase {
public:
    uint8_t readEnvelope() const noexcept;

    void writeEnvelope(uint8_t value) noexcept;

    void stepEnvelope() noexcept;

    void restart() noexcept;

    void reset() noexcept;


protected:
    EnvChannelBase(uint32_t defaultPeriod, unsigned lengthCounterMax) noexcept;

    // contents of the envelope register (NRx2)
    uint8_t mEnvelopeRegister;

    uint8_t mEnvelopeCounter;
    uint8_t mEnvelopePeriod;
    bool mEnvelopeAmplify;
    int8_t mVolume;
};



class PulseChannel : public EnvChannelBase {

public:

    PulseChannel() noexcept;

    //
    // Set the duty of the pulse. Does not require restart.
    //
    void writeDuty(uint8_t duty) noexcept;

    uint8_t readDuty() const noexcept;

    void reset() noexcept;

protected:

    void stepOscillator() noexcept;

    void setPeriod() noexcept;

private:

    uint8_t mDuty;
    uint8_t mDutyWaveform;

    unsigned mDutyCounter;


};

class SweepPulseChannel : public PulseChannel {

public:
    SweepPulseChannel() noexcept;

    uint8_t readSweep() const noexcept;

    void reset() noexcept;

    void restart() noexcept;

    void writeSweep(uint8_t reg) noexcept;

    void stepSweep() noexcept;

private:

    bool mSweepSubtraction;
    uint8_t mSweepTime;
    uint8_t mSweepShift;

    uint8_t mSweepCounter;

    // Sweep register, NR10
    // Bits 0-2: Shift amount
    // Bit    3: Sweep mode (1 = subtraction)
    // Bits 4-6: Period
    uint8_t mSweepRegister;

    // shadow register, CH1's frequency gets copied here on reset (initalization)
    int16_t mShadow;

};

class WaveChannel : public ChannelBase {

public:

    WaveChannel() noexcept;

    uint8_t* waveram() noexcept;

    uint8_t readVolume() const noexcept;

    void reset() noexcept;

    void restart() noexcept;

    void writeVolume(uint8_t volume) noexcept;


protected:

    void stepOscillator() noexcept;

    void setPeriod() noexcept;

private:

    void setOutput();

    //Gbs::WaveVolume mVolume;
    uint8_t mVolumeShift;
    uint8_t mWaveIndex;
    uint8_t mSampleBuffer;
    std::array<uint8_t, 16> mWaveram;


};

class NoiseChannel : public EnvChannelBase {

public:

    NoiseChannel() noexcept;

    uint8_t readNoise() const noexcept;

    void restart() noexcept;

    void reset() noexcept;

protected:
    void stepOscillator() noexcept;

    void setPeriod() noexcept;

private:

    bool mValidScf;

    // width of the LFSR (7-bit = true, 15-bit = false)
    bool mHalfWidth;
    // lfsr: linear feedback shift register
    uint16_t mLfsr;


};

template <class T>
class Channel : public T {

public:
    void writeFrequencyLsb(uint8_t value);

    void writeFrequencyMsb(uint8_t value);

    // steps 2 clocks
    void step();

};


struct ChannelFile {

    Channel<SweepPulseChannel> ch1;
    Channel<PulseChannel> ch2;
    Channel<WaveChannel> ch3;
    Channel<NoiseChannel> ch4;

    ChannelFile() noexcept :
        ch1(),
        ch2(),
        ch3(),
        ch4()
    {
    }

};

class Sequencer : public Timer {

public:

    Sequencer(ChannelFile &cf) noexcept;

    void reset() noexcept;

    void step() noexcept;

private:

    static constexpr uint32_t CYCLES_PER_STEP = 8192;
    static constexpr uint32_t DEFAULT_PERIOD = CYCLES_PER_STEP * 2;

    enum class TriggerType {
        lcSweep,
        lc,
        env
    };

    struct Trigger {
        uint32_t nextIndex;     // next index in the sequence
        uint32_t nextPeriod;    // timer period for the next trigger
        TriggerType type;       // trigger to do
    };

    static Trigger const TRIGGER_SEQUENCE[];

    ChannelFile &mCf;
    uint32_t mTriggerIndex;




};

}

}
