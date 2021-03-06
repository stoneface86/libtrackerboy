
# libtrackerboy

Support library for [Trackerboy](https://github.com/stoneface86/trackerboy).

This library handles:
 * Reading/Writing trackerboy module files
 * Manipulating/reading module data
 * Gameboy APU emulation
 * Module playback
 * (Coming soon) export to [tbengine](https://github.com/stoneface86/tbengine) format.

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
