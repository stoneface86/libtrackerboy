
#pragma once

#include <string>

namespace trackerboy {

class Named {

public:
    Named() = default;

    std::string const& name() const;

    void setName(std::string const& name);
    void setName(std::string&& name);

private:
    std::string mName;
};

}
