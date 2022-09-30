
import libtrackerboy/version
import testing

testunit "version"
testclass "Version"

dtest "version to string":
    check:
        $v() == "0.0.0"
        $v(1, 0, 0) == "1.0.0"
        $v(0, 5, 23) == "0.5.23"

dtest "version comparing":
    check:
        v() == v()
        v(1, 0, 0) != v(0, 1, 0)
        v(1, 0, 0) > v(0, 1, 0)
        v(1, 0, 2) > v(1, 0, 1)
        v(1, 0, 2) >= v(1, 0, 1)
        v(1, 0, 2) >= v(1, 0, 2)
