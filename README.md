
# libtrackerboy

Support library for [Trackerboy](https://github.com/stoneface86/trackerboy).
Also known as the back end of Trackerboy.

This library handles:
 * Reading/Writing trackerboy module files
 * Manipulating/reading module data
 * Game Boy APU emulation
 * Module playback
 * (Coming soon) export to [tbengine](https://github.com/stoneface86/tbengine) format.

## Building

This library package also contains a command line utility, `tbc`
(Trackerboy compiler). To build, simply run `nimble build` from the root of
the project directory. The compiled executable will be located in the `bin/`
directory.

## Testing

The unit tester can be built using the `tester` task
```sh
# build the unit tester
nimble tester
# build and run the unit tester with optional filter
nimble test [filter]
# alternatively:
nimble tester && ./bin/tester [filter]
```

When launching the tester you can supply a filter argument with a wildcard
character(s), `*`, to only run tests whose name matches a certain pattern. If
omitted all tests will run.

### Miscellaneous test programs

There are some extra programs for testing that are not automated. These programs
generate audio files to be verified by ear. To run, use the `apugen` and `wavegen`
nimble tasks.

```sh
# apugen, generates sample audio by testing the APU emulator
# generated audio files are located in ./bin/apugen.d/
nimble apugen

# wavegen, tests the bandlimited synthesis module by generating simple square tones
# generated audio files are located in ./bin/wavegen.d/
nimble wavegen
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
