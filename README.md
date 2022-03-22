
# nim-rewrite branch

This is the `nim-rewrite` branch. This branch contains a rewrite of the
library in the Nim language.

Why Nim?
 - easy C/C++ interop
 - fast, small executable size when compiling to C
 - efficient programming language with amazing metaprogramming support
 - (Opinion) C++ is annoying to work with compared to a modern language like Nim.

Most of Trackerboy will eventually be rewritten in Nim. Except for the frontend,
which will remain in C++ as there are no Nim bindings for Qt.

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

## Authors

 * stoneface ([@stoneface86](https://github.com/stoneface86)) - Owner

## License

This project is licensed under the MIT License - See [LICENSE](LICENSE) for more details
