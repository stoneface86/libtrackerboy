
#pragma once

#include "internal/fileformat/payload/PayloadHandler.hpp"
#include "internal/fileformat/payload/payload.hpp"

#include "trackerboy/data/Table.hpp"

#include <utility>

namespace trackerboy {


template <class T, BlockId tId>
class TableHandler : public PayloadHandler<tId> {

public:
    constexpr TableHandler(size_t count) :
        PayloadHandler<tId>(count),
        mNextId(0)
    {
    }

protected:
    T* initItem(InputBlock &block, Table<T> &table) {
        uint8_t id;
        block.read(id);

        if (table[id] != nullptr) {
            return nullptr;
        }

        auto item = table.insert(id);
        item->setName(deserializeString(block));
        return item;
    }

    auto nextItem(Table<T> const& table) {
        T const* item;
        while ((item = table[mNextId++]) == nullptr);
        return std::make_pair(item, mNextId - 1);
    }

private:
    int mNextId;


};

    
}
