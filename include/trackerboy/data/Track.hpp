/*
** Trackerboy - Gameboy / Gameboy Color music tracker
** Copyright (C) 2019-2020 stoneface86
**
** Permission is hereby granted, free of charge, to any person obtaining a copy
** of this software and associated documentation files (the "Software"), to deal
** in the Software without restriction, including without limitation the rights
** to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
** copies of the Software, and to permit persons to whom the Software is
** furnished to do so, subject to the following conditions:
**
** The above copyright notice and this permission notice shall be included in all
** copies or substantial portions of the Software.
**
** THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
** IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
** FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
** AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
** LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
** OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
** SOFTWARE.
**
*/

#pragma once

#include "trackerboy/data/TrackRow.hpp"

#include <memory>

namespace trackerboy {


// container class for track data

/*!
 * \brief Container class for track data
 *
 * The track class is a container of TrackRow structs. A Pattern is made up
 * of 4 Track objects, one for each channel.
 */
class Track {

public:

    /*!
     * iterator type for the Track container, TrackRow pointer
     */
    using iterator = TrackRow*;

    /*!
     * const iterator type for the Track container
     */
    using const_iterator = TrackRow const*;

    /*!
     * \brief Constructs an empty track
     * \param rows the size of the track in rows
     */
    Track(size_t rows);

    /*!
     * \brief Copy-constructor.
     * \param track the track to copy
     *
     * The track's data is copied from the given \a track.
     */
    Track(Track const& track);

    /*!
     * \brief Copy-assignment.
     * \param lhs the track to copy
     * \return a reference to this
     *
     * This track's data is replaced with a copy of the given \a track's data.
     */
    Track& operator=(Track const& lhs);

    // allow moves, but the moved track will be invalid and no longer usable

    Track(Track &&track) = default;
    Track& operator=(Track &&track) = default;


    /*!
     * \brief Access the row at the given index.
     * \param row index of the row to access
     * \return a reference to the row data
     *
     * Similar to STL [] overloads, these overloads will not check if the
     * index is in bounds.
     */
    TrackRow& operator[](size_t row);

    /*!
     * \brief Access the row at the given index (read-only).
     * \param row index of the row to access
     * \return a const reference to the row data
     * \sa operator[](size_t)
     */
    TrackRow const& operator[](size_t row) const;

    iterator begin();
    const_iterator begin() const;

    void clear(size_t rowStart, size_t rowEnd);

    void clearEffect(size_t row, size_t effectNo);

    void clearInstrument(size_t row);

    void clearNote(size_t row);

    iterator end();
    const_iterator end() const;

    void setEffect(size_t row, size_t effectNo, EffectType effect, uint8_t param = 0);

    void setInstrument(size_t row, uint8_t instrumentId);

    void setNote(size_t row, uint8_t note);

    void resize(size_t newSize);

    int rowCount() const;

    size_t size() const;

private:

    void checkIndex(size_t row) const;

    void checkEffectNo(size_t effectNo) const;

    void checkSize(size_t size) const;

    std::unique_ptr<TrackRow[]> mData;
    size_t mRows;


};



}
