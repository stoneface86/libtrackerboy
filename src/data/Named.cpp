
#include "trackerboy/data/Named.hpp"

namespace trackerboy {

std::string const& Named::name() const {
    return mName;
}

void Named::setName(std::string const& name) {
    mName = name;
}

void Named::setName(std::string&& name) {
    mName = std::move(name);
}

}
