
#include <algorithm>

#include "trackerboy/engine/Timer.hpp"

//
// The Timer class is used for counting frames. 
//
// Period = 2.5 (00010.100) 
// A   O | A   O   | A
// 0 1 2 | 0.5 1.5 | 0
//
// At frame #0 the timer is active (A) since the counter is < 1.0, at frame #2 the timer overflows (O)
//


namespace trackerboy {

namespace {

static constexpr Speed UNIT_SPEED = 8; // 8 = 00001.000 = 1.0 (Q5.3)

}


Timer::Timer() noexcept :
    mPeriod(DEFAULT_PERIOD),
    mCounter(0)
{
}

bool Timer::active() const noexcept {
    return mCounter < UNIT_SPEED;
}

Speed Timer::period() const noexcept {
    return mPeriod;
}

void Timer::reset() noexcept {
    mCounter = 0;
}

void Timer::setPeriod(Speed period) noexcept {
    mPeriod = std::min(std::max(period, SPEED_MIN), SPEED_MAX);
    // might need to adjust mCounter
}

bool Timer::step() noexcept {
    mCounter += UNIT_SPEED;
    if (mCounter >= mPeriod) {
        mCounter -= mPeriod;
        // timer overflow
        return true;
    } else {
        return false;
    }
}



}
