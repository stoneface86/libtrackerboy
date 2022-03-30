{.used.}

import std/unittest
import trackerboy/version

test "version to string":
    check $v() == "0.0.0"
    check $v(1, 0, 0) == "1.0.0"
    check $v(0, 5, 23) == "0.5.23"

test "version comparing":
    check v() == v()
    check v(1, 0, 0) != v(0, 1, 0)
    check v(1, 0, 0) > v(0, 1, 0)
    check v(1, 0, 2) > v(1, 0, 1)
    check v(1, 0, 2) >= v(1, 0, 1)
    check v(1, 0, 2) >= v(1, 0, 2)
