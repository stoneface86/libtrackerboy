
#include "trackerboy/data/Track.hpp"

#include <algorithm>
#include <stdexcept>

namespace trackerboy {

namespace {

constexpr TrackRow NULL_ROW = {};
constexpr Effect NULL_EFFECT = { EffectType::noEffect, 0 };

}

Track::Track(size_t rows) :
    mData(),
    mRows(rows)
{
    checkSize(rows);

    mData = std::make_unique<TrackRow[]>(rows);
    clear(0, rows);
}

Track::Track(Track const& track) :
    mData(),
    mRows(0)
{
    operator=(track);
}

Track& Track::operator=(const Track &lhs) {
    if (mRows != lhs.mRows) {
        mRows = lhs.mRows;
        mData = std::make_unique<TrackRow[]>(mRows);
    }

    std::copy_n(lhs.mData.get(), mRows, mData.get());
    return *this;
}


TrackRow& Track::operator[](size_t row) {
    return mData[row];
}

TrackRow const& Track::operator[](size_t row) const {
    return mData[row];
}

Track::iterator Track::begin() {
    return mData.get();
}

Track::const_iterator Track::begin() const {
    return mData.get();
}

void Track::clear(size_t rowStart, size_t rowEnd) {
    if (rowStart > rowEnd || rowEnd > mRows) {
        throw std::invalid_argument("invalid range to clear");
    }

    std::fill_n(mData.get() + rowStart, rowEnd - rowStart, NULL_ROW);

}

void Track::clearEffect(size_t rowNo, size_t effectNo) {
    checkIndex(rowNo);
    checkEffectNo(effectNo);

    auto &row = mData[rowNo];
    row.effects[effectNo] = NULL_EFFECT;

}

void Track::clearInstrument(size_t rowNo) {
    checkIndex(rowNo);
    auto &row = mData[rowNo];
    row.setInstrument({});

}

void Track::clearNote(size_t rowNo) {
    checkIndex(rowNo);
    auto &row = mData[rowNo];
    row.setNote({});
}

Track::iterator Track::end() {
    return mData.get() + mRows;
}

Track::const_iterator Track::end() const {
    return mData.get() + mRows;
}

void Track::setEffect(size_t rowNo, size_t effectNo, EffectType effect, uint8_t param) {
    checkIndex(rowNo);
    checkEffectNo(effectNo);

    if (effect == EffectType::noEffect) {
        clearEffect(rowNo, effectNo);
        return;
    }

    auto &row = mData[rowNo];
    auto &effectSt = row.effects[effectNo];
    effectSt.type = effect;
    effectSt.param = param;
}

void Track::setInstrument(size_t rowNo, uint8_t instrumentId) {
    checkIndex(rowNo);
    auto &row = mData[rowNo];
    row.setInstrument(instrumentId);
}

void Track::setNote(size_t rowNo, uint8_t note) {
    checkIndex(rowNo);
    auto &row = mData[rowNo];
    row.setNote(note);
}

void Track::resize(size_t newSize) {
    checkSize(newSize);
    if (newSize != mRows) {
        // resize needed

        // create a new buffer
        auto newBuf = std::make_unique<TrackRow[]>(newSize);

        // copy from old to new
        auto const toCopy = std::min(newSize, mRows);
        std::copy_n(mData.get(), toCopy, newBuf.get());

        // clear (if needed)
        std::fill_n(newBuf.get() + toCopy, newSize - toCopy, NULL_ROW);

        // update class members with new buffer
        mData = std::move(newBuf);
        mRows = newSize;

    }
}

int Track::rowCount() const {
    int count = 0;

    for (auto &row : *this) {
        if (!row.isEmpty()) {
            ++count;
        }
    }


    return count;
}

size_t Track::size() const {
    return mRows;
}

void Track::checkEffectNo(size_t effectNo) const {
    if (effectNo >= TrackRow::MAX_EFFECTS) {
        throw std::invalid_argument("invalid effect no");
    }
}

void Track::checkIndex(size_t row) const {
    if (row >= mRows) {
        throw std::invalid_argument("invalid row index");
    }
}

void Track::checkSize(size_t size) const {
    if (size == 0 || size > 256) {
        throw std::invalid_argument("invalid track size");
    }
}

bool operator==(Track const& lhs, Track const& rhs) noexcept {
    if (lhs.mRows == rhs.mRows) {
        return std::equal(lhs.mData.get(), lhs.mData.get() + lhs.mRows, rhs.mData.get());
    }
    return false;
}

bool operator!=(Track const& lhs, Track const& rhs) noexcept {
    return !(lhs == rhs);
}

}
