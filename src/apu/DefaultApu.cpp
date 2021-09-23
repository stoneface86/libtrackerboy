
#include "trackerboy/apu/DefaultApu.hpp"
#include "internal/apu.hpp"

#include <algorithm>
#include <optional>
#include <cmath>

namespace trackerboy {

#define TU DefaultApuTU
namespace TU {



}

class DefaultApu::Private {


public:
    Private() :
        mNr51(0),
        mLeftVolume(1),
        mRightVolume(1),
        mMixer(),
        mHardware(),
        mCycletime(0),
        mEnabled(false),
        mVolumeStep(0.0f)
    {
        setVolume(1.0f);
    }

    void reset() {
        mCycletime = 0;
        mMixer.clear();
        mHardware.reset();
        mLeftVolume = 1;
        mRightVolume = 1;
        mEnabled = false;
        updateVolume();
    }

    void step(uint32_t cycles) {
        mHardware.run(mMixer, mCycletime, cycles);
        mCycletime += cycles;
    }

    void endFrameAt(uint32_t time) {
        if (time < mCycletime) {
            return;
        }

        auto toStep = time - mCycletime;
        if (toStep) {
            step(toStep);
        }
        mMixer.endFrame(time);
        mCycletime = 0;
    }

    int channelVolume(ChType ch) {
        switch (ch) {
            case ChType::ch1:
                return mHardware.envelope<0>().volume();
            case ChType::ch2:
                return mHardware.envelope<1>().volume();
            case ChType::ch3:
                switch (mHardware.channel<2>().volume()) {
                    case apu::WaveChannel::VolumeMute:
                        return 0;
                    case apu::WaveChannel::VolumeFull:
                        return 3;
                    case apu::WaveChannel::VolumeHalf:
                        return 2;
                    default:
                        return 1;
                }
            default:
                return mHardware.envelope<3>().volume();
        }
    }

    uint8_t readRegister(uint8_t reg) {
        /*
        * Read masks
        *      NRx0 NRx1 NRx2 NRx3 NRx4
        *     ---------------------------
        * NR1x  $80  $3F $00  $FF  $BF
        * NR2x  $FF  $3F $00  $FF  $BF
        * NR3x  $7F  $FF $9F  $FF  $BF
        * NR4x  $FF  $FF $00  $00  $BF
        * NR5x  $00  $00 $70
        *
        * $FF27-$FF2F always read back as $FF
        */


        // TODO: length counters can still be accessed on DMG when powered off
        if (!mEnabled && reg < REG_NR52) {
            // APU is disabled, ignore this read
            return 0xFF;
        }

        switch (reg) {
            // ===== CH1 =====

            case REG_NR10:
                return mHardware.sweep().readRegister();
            case REG_NR11:
                return 0x3F | (mHardware.channel<0>().duty() << 6);
            case REG_NR12:
                return mHardware.envelope<0>().readRegister();
            case REG_NR13:
                return 0xFF;
            case REG_NR14:
                return mHardware.lengthCounter<0>().isEnabled() ? 0xFF : 0xBF;

            // ===== CH2 =====

            case REG_NR21:
                return 0x3F | (mHardware.channel<1>().duty() << 6);
            case REG_NR22:
                return mHardware.envelope<1>().readRegister();
            case REG_NR23:
                return 0xFF;
            case REG_NR24:
                return mHardware.lengthCounter<1>().isEnabled() ? 0xFF : 0xBF;

            // ===== CH3 =====

            case REG_NR30:
                return mHardware.channel<2>().isDacOn() ? 0xFF : 0x7F;
            case REG_NR31:
                return 0xFF;
            case REG_NR32:
                return 0x9F | (mHardware.channel<2>().volume() << 5);
            case REG_NR33:
                return 0xFF;
            case REG_NR34:
                return mHardware.lengthCounter<2>().isEnabled() ? 0xFF : 0xBF;

            // ===== CH4 =====

            case REG_NR41:
                return 0xFF;
            case REG_NR42:
                return mHardware.envelope<3>().readRegister();
            case REG_NR43:
                return mHardware.channel<3>().frequency() & 0xFF;
            case REG_NR44:
                return mHardware.lengthCounter<3>().isEnabled() ? 0xFF : 0xBF;

           // ===== Sound control ======

            case REG_NR50:
                // Not implemented: Vin, always read back as 0
                return ((mLeftVolume - 1) << 4) | (mRightVolume - 1);
            case REG_NR51:
                return mNr51;
            case REG_NR52:
            {
                uint8_t nr52 = mEnabled ? 0xF0 : 0x70;
                if (mHardware.channel<0>().isDacOn()) {
                    nr52 |= 0x1;
                }
                if (mHardware.channel<1>().isDacOn()) {
                    nr52 |= 0x2;
                }
                if (mHardware.channel<2>().isDacOn()) {
                    nr52 |= 0x4;
                }
                if (mHardware.channel<3>().isDacOn()) {
                    nr52 |= 0x8;
                }
                return nr52;
            }

            case REG_WAVERAM:
            case REG_WAVERAM + 1:
            case REG_WAVERAM + 2:
            case REG_WAVERAM + 3:
            case REG_WAVERAM + 4:
            case REG_WAVERAM + 5:
            case REG_WAVERAM + 6:
            case REG_WAVERAM + 7:
            case REG_WAVERAM + 8:
            case REG_WAVERAM + 9:
            case REG_WAVERAM + 10:
            case REG_WAVERAM + 11:
            case REG_WAVERAM + 12:
            case REG_WAVERAM + 13:
            case REG_WAVERAM + 14:
            case REG_WAVERAM + 15:
                if (auto &ch = mHardware.channel<2>(); !ch.isDacOn()) {
                    return ch.waveram()[reg - REG_WAVERAM];
                }
                return 0xFF;
            default:
                return 0xFF;
        }
    }


    void writeRegister(uint8_t reg, uint8_t value) {
        // TODO: length counters can still be accessed on DMG when powered off
        if (!mEnabled && reg < REG_NR52) {
            // APU is disabled, ignore this write
            return;
        }

        switch (reg) {
            case REG_NR10:
                mHardware.sweep().writeRegister(value);
                break;
            case REG_NR11:
                mHardware.channel<0>().setDuty(value >> 6);
                mHardware.lengthCounter<0>().setCounter(value & 0x3F);
                break;
            case REG_NR12:
                mHardware.writeEnvelope<0>(value);
                break;
            case REG_NR13:
                mHardware.writeFrequencyLsb<0>(value);
                break;
            case REG_NR14:
                mHardware.writeFrequencyMsb<0>(value);
                break;
            case REG_NR21:
                mHardware.channel<1>().setDuty(value >> 6);
                mHardware.lengthCounter<1>().setCounter(value & 0x3F);
                break;
            case REG_NR22:
                mHardware.writeEnvelope<1>(value);
                break;
            case REG_NR23:
                mHardware.writeFrequencyLsb<1>(value);
                break;
            case REG_NR24:
                mHardware.writeFrequencyMsb<1>(value);
                break;
            case REG_NR30:
                mHardware.channel<2>().setDacEnabled(!!(value & 0x80));
                break;
            case REG_NR31:
                mHardware.lengthCounter<2>().setCounter(value);
                break;
            case REG_NR32:
                mHardware.channel<2>().setVolume((value >> 5) & 0x3);
                break;
            case REG_NR33:
                mHardware.writeFrequencyLsb<2>(value);
                break;
            case REG_NR34:
                mHardware.writeFrequencyMsb<2>(value);
                break;
            case REG_NR41:
                mHardware.lengthCounter<3>().setCounter(value & 0x3F);
                break;
            case REG_NR42:
                mHardware.writeEnvelope<3>(value);
                break;
            case REG_NR43:
                mHardware.writeFrequencyLsb<3>(value);
                break;
            case REG_NR44:
                mHardware.writeFrequencyMsb<3>(value);
                break;
            case REG_NR50: {
                // do nothing with the Vin bits
                // Vin will not be emulated since no cartridge in history ever made use of it
                mLeftVolume = ((value >> 4) & 0x7) + 1;
                mRightVolume = (value & 0x7) + 1;

                // a change in volume will require a transition to the new volume step
                // this transition is done by modifying the DC offset

                auto oldVolumeLeft = mMixer.leftVolume();
                auto oldVolumeRight = mMixer.rightVolume();

                // calculate and set the new volume in the mixer
                updateVolume();

                // volume differentials
                auto leftVolDiff = mMixer.leftVolume() - oldVolumeLeft;
                auto rightVolDiff = mMixer.rightVolume() - oldVolumeRight;

                float dcLeft = 0.0f;
                float dcRight = 0.0f;

                auto const& mix = mHardware.mix();
                for (size_t i = 0; i != mix.size(); ++i) {
                    auto mode = mix[i];
                    auto output = mHardware.lastOutput(i) - 7.5f;

                    if (apu::modePansLeft(mode)) {
                        dcLeft += leftVolDiff * output;
                    }
                    if (apu::modePansRight(mode)) {
                        dcRight += rightVolDiff * output;
                    }

                }
                mMixer.mixDc(dcLeft, dcRight, mCycletime);
                break;
            }
            case REG_NR51: {
                mNr51 = value;
                auto panning = value;
                apu::ChannelMix mix;
                for (size_t i = 0; i != mix.size(); ++i) {
                    switch (panning & 0x11) {
                        case 0x00:
                            mix[i] = apu::MixMode::mute;
                            break;
                        case 0x01:
                            mix[i] = apu::MixMode::right;
                            break;
                        case 0x10:
                            mix[i] = apu::MixMode::left;
                            break;
                        case 0x11:
                            mix[i] = apu::MixMode::middle;
                            break;
                    }

                    panning >>= 1;
                }
                mHardware.setMix(mix, mMixer, mCycletime);

                break;
            }
            case REG_NR52:
                if (!!(value & 0x80) != mEnabled) {

                    if (mEnabled) {
                        // shutdown
                        // zero out all registers
                        for (uint8_t i = REG_NR10; i != REG_NR52; ++i) {
                            writeRegister(i, 0);
                        }
                        mEnabled = false;
                    } else {
                        // startup
                        mEnabled = true;
                        //mHf.gen1.softReset();
                        //mHf.gen2.softReset();
                        //mHf.gen3.softReset();
                        //mSequencer.reset();
                    }

                }
                break;
            case REG_WAVERAM:
            case REG_WAVERAM + 1:
            case REG_WAVERAM + 2:
            case REG_WAVERAM + 3:
            case REG_WAVERAM + 4:
            case REG_WAVERAM + 5:
            case REG_WAVERAM + 6:
            case REG_WAVERAM + 7:
            case REG_WAVERAM + 8:
            case REG_WAVERAM + 9:
            case REG_WAVERAM + 10:
            case REG_WAVERAM + 11:
            case REG_WAVERAM + 12:
            case REG_WAVERAM + 13:
            case REG_WAVERAM + 14:
            case REG_WAVERAM + 15:
                // if CH3's DAC is enabled, then the write goes to the current waveposition
                // this can only be done within a few clocks when CH3 accesses waveram, otherwise the write has no effect
                // this behavior was fixed for the CGB, so we can access waveram whenever
                if (auto &ch = mHardware.channel<2>(); !ch.isDacOn()) {
                    ch.waveram()[reg - REG_WAVERAM] = value;
                }
                // ignore write if enabled
                break;
            default:
                return;
        }
    }

    void setVolume(float gain) {

        // max amp on each channel is 15 so max amp is 60
        // 8 master volume levels so 60 * 8 = 480
        mVolumeStep = gain / 480;
        updateVolume();

    }

private:

    void updateVolume() {
        // apply global volume settings
        auto leftVol = mLeftVolume * mVolumeStep;
        auto rightVol = mRightVolume * mVolumeStep;
        mMixer.setVolume(leftVol, rightVol);
    }

    friend class DefaultApu;

    uint8_t mNr51;
    uint8_t mLeftVolume;
    uint8_t mRightVolume;
    apu::Mixer mMixer;
    apu::Hardware mHardware;

    uint32_t mCycletime;
    bool mEnabled;

    float mVolumeStep;

};

DefaultApu::DefaultApu() :
    mD(std::make_unique<Private>())
{
}

DefaultApu::~DefaultApu() {

}

void DefaultApu::step(uint32_t cycles) {
    mD->step(cycles);
}

void DefaultApu::endFrameAt(uint32_t time) {
    mD->endFrameAt(time);
}

size_t DefaultApu::samplesAvailable() {
    return mD->mMixer.availableSamples();
}

size_t DefaultApu::readSamples(float *buf, size_t samples) {
    return mD->mMixer.readSamples(buf, samples);
}

void DefaultApu::setBuffer(size_t samples) {
    mD->mMixer.setBuffer(samples);
}

void DefaultApu::setSamplerate(int rate) {
    mD->mMixer.setSamplerate(rate);
}

void DefaultApu::reset() {
    mD->reset();
}

int DefaultApu::channelVolume(ChType ch) {
    return mD->channelVolume(ch);
}

// IApuIo implementation

uint8_t DefaultApu::readRegister(uint8_t reg) {
    return mD->readRegister(reg);
}

void DefaultApu::writeRegister(uint8_t reg, uint8_t value) {
    mD->writeRegister(reg, value);
}

}
