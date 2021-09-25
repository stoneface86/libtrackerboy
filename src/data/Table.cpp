
#include "trackerboy/data/Table.hpp"

#include <algorithm>
#include <cassert>
#include <stdexcept>

namespace trackerboy {

#define TU TableTU
namespace TU {

constexpr auto TABLE_SIZE = InstrumentTable::MAX_SIZE;

constexpr inline bool idIsValid(int id) {
    if constexpr (((TABLE_SIZE - 1) & TABLE_SIZE) == 0) {
        return (id & ~(TABLE_SIZE - 1)) == 0;
    } else {
        return id >= 0 && id < TABLE_SIZE;
    }
}

}


template <class T>
Table<T>::Table() :
    mContainer(),
    mNextId(0)
{
}

template <class T>
T const* Table<T>::operator[](int id) const {
    return get(id);
}

template <class T>
T* Table<T>::operator[](int id) {
    return get(id);
}

template <class T>
void Table<T>::clear() {
    mContainer.clear();
    mNextId = 0;
}

template <class T>
int Table<T>::nextAvailableId() const {
    return mNextId;
}

template <class T>
T* Table<T>::insert() {
    if (size() == MAX_SIZE) {
        return nullptr;
    }
    auto result = insertImpl(mNextId);
    updateNextId();
    return result;
}

template <class T>
T* Table<T>::insert(int index) {
    if (!TU::idIsValid(index) || mContainer.find(index) != mContainer.end()) {
        return nullptr; // can't insert, table is either full, an item already has this id or the id was invalid
    }
    if (index == mNextId) {
        updateNextId();
    }
    return insertImpl(index);

}

template <class T>
T* Table<T>::insertImpl(int index) {
    auto result = mContainer.emplace(index, std::make_shared<T>());
    assert(result.second);

    return result.first->second.get();
}

template <class T>
T* Table<T>::duplicate(int id) {
    if (size() == MAX_SIZE || !TU::idIsValid(id)) {
        return nullptr; // can't insert, table is full
    }

    auto iter = mContainer.find(id);
    if ( iter == mContainer.end()) {
        return nullptr; // cannot duplicate, item does not exist
    }

    auto result = mContainer.emplace(mNextId, std::make_shared<T>(*iter->second.get()));
    assert(result.second);

    updateNextId();
    return result.first->second.get();
}

template <class T>
std::shared_ptr<T> const* Table<T>::getPointer(int id) const {
    if (TU::idIsValid(id)) {
        if (auto iter = mContainer.find(id); iter != mContainer.end()) {
            return &iter->second;
        }
    }

    return nullptr;
}

template <class T>
T* Table<T>::get(int id) {
    return const_cast<T*>(
                static_cast<const Table<T>*>(this)->get(id)
                );
}

template <class T>
T const* Table<T>::get(int id) const {
    if (auto ptr = getPointer(id); ptr) {
        return (*ptr).get();
    }

    return nullptr;
}

template <class T>
std::shared_ptr<T> Table<T>::getShared(int id) {
    // this is kinda wasteful, getShared returns a new shared_ptr and
    // then casting it creates another shared_ptr
    return std::const_pointer_cast<T>(
                static_cast<const Table<T>*>(this)->getShared(id)
                );
}

template <class T>
std::shared_ptr<const T> Table<T>::getShared(int id) const {
    if (auto ptr = getPointer(id); ptr) {
        return *ptr;
    }

    // id was invalid or there is no item with this id
    return nullptr;
}

template <class T>
void Table<T>::remove(int index) {
    auto removed = mContainer.erase(index);
    if (removed && mNextId > index) {
        mNextId = index;
    }
}

template <class T>
size_t Table<T>::size() const {
    return mContainer.size();
}

template <class T>
void Table<T>::updateNextId() {
    if (size() < MAX_SIZE) {
        // find the next available id
        while (mContainer.find(++mNextId) != mContainer.end());
    }
}


template class Table<Instrument>;
template class Table<Waveform>;

}

#undef TU
