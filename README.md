
# libtrackerboy

Support library for [TrackerBoy](https://github.com/stoneface86/trackerboy).
Also known as the back end of TrackerBoy.

This library handles:
 * Reading/Writing trackerboy module files
 * Manipulating/reading module data
 * Game Boy APU emulation
 * Module playback
 * (Coming soon) export to [tbengine](https://github.com/stoneface86/tbengine) format.

## Install

Install via nimble or atlas

```sh
# nimble
nimble install https://github.com/stoneface86/libtrackerboy/
# atlas
atlas use https://github.com/stoneface86/libtrackerboy/
```

## Build tasks

Tasks for building tests, documentation, etc, are located in
[build.nims](build.nims). This nimscript is included by config.nims and
libtrackerboy.nimble, so they are available via `nim` when using atlas and
`nimble` when using nimble.

## Testing

The unit tester can be run using the `test` task
```sh
# build and run the unit tester with optional test name matchers
nim test [matchers...]
```

When launching the tester you can supply any number of matcher arguments that
when specified will only run the tests that match the names given. Use wildcard
character(s), `*`, as a glob to match 0 or more characters in the name. If
no matchers are given, all tests will run.

The names of each test in the tester use the following syntax:
```
modulename[.classname].testname
 
 - modulename: The name of the module in the library being tested
 - classname: An optional category, typically the name of the type being tested
 - testname: The name of the test, or a description of what's being tested
```

### Examples

```sh
# Runs everything
nim test
# Runs all tests for the common and io modules
nim test common.\* io.\*
# Runs all tests for the Immutable type defined in the common module
nim test common.Immutable.\*
```

### unittest2

[unittest2][unittest2-link] is used as the unit testing framework, as it
provides parallel test execution unlike std/unittest. For performance reasons,
test suites are not used, as they impose a barrier before and after each suite
during execution. If you require `setup` and `teardown` functionality that
suites provide, use `testgroup` instead, which is provided by the
[testing module](tests/units/testing.nim).

### Miscellaneous test programs

There are some extra programs for testing that are not automated. The source
for these programs are located in [tests/standalones](tests/standalones).
These programs generate audio files to be verified by ear. To run, use the
apugen and wavegen tasks.

```sh
# apugen, generates sample audio by testing the APU emulator
# generated audio files are located in ./bin/apugen.d/
nim apugen

# wavegen, tests the bandlimited synthesis module by generating simple square tones
# generated audio files are located in ./bin/wavegen.d/
nim wavegen
```

## Migration from Trackerboy

The source for this library was originally kept in the trackerboy repo, but has
been relocated this repo. This was done to keep things modular, so that the
library can easily be used in other projects.

## Versioning

This project uses Semantic Versioning v2.0.0

## C++ library

This library was previously written in C++ and is now written in Nim. The C++
version is no longer mantained. The [cpp-last][1] tag
points to the last commit that contains the C++ version.

[1]: https://github.com/stoneface86/libtrackerboy/releases/tag/cpp-last

## Authors

 * stoneface ([@stoneface86](https://github.com/stoneface86)) - Owner

## License

This project is licensed under the MIT License - See [LICENSE](LICENSE) for more details

[unittest2-link]: https://github.com/status-im/nim-unittest2
