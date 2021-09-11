
#include "trackerboy/Version.hpp"

#include <sstream>


namespace trackerboy {

std::string Version::toString() {
    std::ostringstream out;
    out << major << "." << minor << "." << patch;
    return out.str();
}

bool operator==(const Version &lhs, const Version &rhs) {
    return lhs.major == rhs.major && lhs.minor == rhs.minor && lhs.patch == rhs.patch;
}

bool operator<(const Version &lhs, const Version &rhs) {
    if (lhs.major == rhs.major) {
        if (lhs.minor == rhs.minor) {
            return lhs.patch < rhs.patch;
        } else {
            return lhs.minor < rhs.minor;
        }
    } else {
        return lhs.major < rhs.major;
    }
}


}
