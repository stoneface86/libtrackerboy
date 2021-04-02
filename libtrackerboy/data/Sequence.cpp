
#include "trackerboy/data/Sequence.hpp"

namespace trackerboy {

Sequence::Sequence() :
    mData(),
    mLoop()
{
}

Sequence::Sequence(Sequence const& seq) :
    mData(seq.mData),
    mLoop(seq.mLoop)
{
}

void Sequence::resize(size_t size) {
    mData.resize(size);
    if (mLoop && *mLoop >= size) {
        mLoop.reset();
    }
}

void Sequence::setLoop(uint8_t loop) {
    mLoop = loop;
}

void Sequence::removeLoop() {
    mLoop.reset();
}


Sequence::Enumerator Sequence::enumerator() const {
    return { *this };
}

Sequence::Enumerator::Enumerator(Sequence const& seq) :
    mSequence(seq),
    mIndex(0)
{
}

std::optional<uint8_t> Sequence::Enumerator::next() {
    auto const seqsize = mSequence.mData.size();
    if (mIndex >= seqsize) {
        if (seqsize != 0 && mSequence.mLoop) {
            mIndex = *mSequence.mLoop;
        } else {
            return std::nullopt;
        }
    }

    auto curr = mSequence.mData[mIndex];
    ++mIndex;

    return curr;

}

}

