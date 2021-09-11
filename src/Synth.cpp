
#include "trackerboy/Synth.hpp"

#include <cmath>


namespace trackerboy {


Synth::Synth(IApu &apu, int samplerate, float framerate) noexcept :
    mApu(apu),
    mSamplerate(samplerate),
    mFramerate(framerate),
    mCyclesPerFrame(GB_CLOCK_SPEED<float> / mFramerate),
    mCycleOffset(0.0f),
    mFrameSize(0),
    mResizeRequired(true)
{
    setupBuffers();
}

size_t Synth::framesize() const noexcept {
    return mFrameSize;
}

void Synth::run() noexcept {

    // determine number of cycles to run for the next frame
    float cycles = mCyclesPerFrame + mCycleOffset;
    float wholeCycles;
    mCycleOffset = modff(cycles, &wholeCycles);

    // step to the end of the frame
    mApu.endFrameAt(static_cast<uint32_t>(wholeCycles));
}


void Synth::reset() noexcept {
    mApu.reset();
    mCycleOffset = 0.0f;

    // turn sound on
    mApu.writeRegister(IApu::REG_NR52, 0x80);
    mApu.writeRegister(IApu::REG_NR50, 0x77);
}

void Synth::setFramerate(float framerate) {
    if (mFramerate != framerate) {
        mFramerate = framerate;
        mResizeRequired = true;
    }
}

int Synth::samplerate() const noexcept {
    return mSamplerate;
}

void Synth::setSamplerate(int samplerate) {
    if (mSamplerate != samplerate) {
        mSamplerate = samplerate;
        mResizeRequired = true;
    }
}

void Synth::setupBuffers() {
    if (mResizeRequired) {
        mCyclesPerFrame = GB_CLOCK_SPEED<float> / mFramerate;
        mFrameSize = static_cast<size_t>(mSamplerate / mFramerate) + 1;

        mApu.setSamplerate(mSamplerate);
        mApu.setBuffer(mFrameSize);

        reset();
        mResizeRequired = false;
    }

    
}

}
