/*
** Trackerboy - Gameboy / Gameboy Color music tracker
** Copyright (C) 2019-2021 stoneface86
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

#include "trackerboy/data/Instrument.hpp"
#include "trackerboy/data/Waveform.hpp"

#include <cstddef>
#include <memory>
#include <unordered_map>

namespace trackerboy {

template <class T>
class Table {

public:

    static constexpr size_t MAX_SIZE = 64;

    Table();

    T* operator[](int id);
    T const* operator[](int id) const;

    void clear();

    int nextAvailableId() const;

    T* insert();

    T* insert(int index);

    T* duplicate(int id);

    T* get(int id);
    T const* get(int id) const;

    std::shared_ptr<T> getShared(int id);
    std::shared_ptr<const T> getShared(int id) const;

    void remove(int id);

    size_t size() const;


private:

    //
    // Gets a reference to the shared pointer for the index. nullptr
    // is returned if the index was invalid or the item does not exist
    // (used by both get and getShared functions).
    //
    std::shared_ptr<T> const* getPointer(int index) const;

    T* insertImpl(int index);

    void updateNextId();

    using Container = std::unordered_map<int, std::shared_ptr<T>>;

    Container mContainer;
    int mNextId;


};



// we will only use these template instantiations

using InstrumentTable = Table<Instrument>;
using WaveformTable = Table<Waveform>;

}
