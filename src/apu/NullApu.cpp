
#include "trackerboy/apu/NullApu.hpp"

namespace trackerboy {

void NullApu::step(uint32_t cycles) {
    (void)cycles;
}

void NullApu::endFrameAt(uint32_t time) {
    (void)time;
}

size_t NullApu::samplesAvailable() {
    return 0;
}

size_t NullApu::readSamples(int16_t *buf, size_t samples) {
    (void)buf;
    (void)samples;
    return 0;
}

void NullApu::setBuffer(size_t samples) {
    (void)samples;
}

void NullApu::setSamplerate(int rate) {
    (void)rate;
}

void NullApu::reset() {
}



uint8_t NullApu::readRegister(uint8_t reg) {
    (void)reg;
    return (uint8_t)0;
}

void NullApu::writeRegister(uint8_t reg, uint8_t value) {
    (void)reg;
    (void)value;
    // do nothing
}

}
