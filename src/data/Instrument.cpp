
#include "trackerboy/data/Instrument.hpp"

namespace trackerboy {

Instrument::Instrument() :
    Named(),
    mChannel(ChType::ch1),
    mEnvelopeEnabled(false),
    mEnvelope(0),
    mSequences()
{
}

ChType Instrument::channel() const noexcept {
    return mChannel;
}

bool Instrument::hasEnvelope() const noexcept {
    return mEnvelopeEnabled;
}

uint8_t Instrument::envelope() const noexcept {
    return mEnvelope;
}

std::optional<uint8_t> Instrument::queryEnvelope() const noexcept {
    if (mEnvelopeEnabled) {
        return mEnvelope;
    } else {
        return std::nullopt;
    }
}

Instrument::SequenceArray& Instrument::sequences() noexcept {
    return mSequences;
}

Instrument::SequenceArray const& Instrument::sequences() const noexcept {
    return mSequences;
}

Sequence::Enumerator Instrument::enumerateSequence(size_t parameter) const noexcept {
    return mSequences[parameter].enumerator();
}

Sequence& Instrument::sequence(size_t parameter) noexcept {
    return mSequences[parameter];
}

Sequence const& Instrument::sequence(size_t parameter) const noexcept {
    return mSequences[parameter];
}

void Instrument::setChannel(ChType ch) noexcept {
    mChannel = ch;
}

void Instrument::setEnvelope(uint8_t envelope) noexcept {
    mEnvelope = envelope;
}

void Instrument::setEnvelopeEnable(bool enable) noexcept {
    mEnvelopeEnabled = enable;
}

bool operator==(Instrument const& lhs, Instrument const& rhs) noexcept {
    return lhs.mChannel == rhs.mChannel &&
           lhs.mEnvelopeEnabled == rhs.mEnvelopeEnabled &&
           lhs.mEnvelope == rhs.mEnvelope &&
           lhs.mSequences == rhs.mSequences;
}

bool operator!=(Instrument const& lhs, Instrument const& rhs) noexcept {
    return !(lhs == rhs);
}

}
