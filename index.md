## Welcome

libtrackerboy is a support library for the [Trackerboy][trackerboy-repo-link].
This library is also known as the back end of Trackerboy, used by the graphical front end, [Trackerboy][trackerboy-repo-link], and
the command line front end, [tbc][tbc-repo-link].

The library handles:
 * Reading/Writing trackerboy module files
 * Manipulating/reading module data
 * Gameboy APU emulation
 * Module playback
 * (Coming soon) export to [tbengine](https://github.com/stoneface86/tbengine) format.

## Documentation

 * [develop branch](docs/develop/)

## Use

You will need:
 - [Nim](https://nim-lang.org/install.html)

```sh
nimble install https://github.com/stoneface86/libtrackerboy
```

[trackerboy-repo-link]: https://github.com/stoneface86/trackerboy
[tbc-repo-link]: https://github.com/stoneface86/tbc
