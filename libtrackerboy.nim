##[

libtrackerboy is a utility library used by trackerboy, a Game Boy tracker. This
library provides the core functionality needed by the UI, and is also known as
the backend.

Looking for trackerboy?
* The repository for the desktop application is [here](https://github.com/stoneface86/trackerboy)
* Click [here](https://trackerboy.org/manual) for the user manual.

This library handles:
* Game Boy APU emulation and sound synthesis
* Manipulating module data
* Module playback and exports
* Reading/Writing module files

## Usage

```nim
import libtrackerboy                   # import everything
import libtrackerboy/[data, io]        # import specific modules (Recommended)
```

### Available modules

| Module                                  | Description                                    |
|-----------------------------------------|------------------------------------------------|
| [apu](libtrackerboy/apu.html)           | Game Boy APU emulation                         |
| [apuio](libtrackerboy/apuio.html)       | APU I/O access, provides ApuIo concept         |
| [common](libtrackerboy/common.html)     | Common types/procs used throughout the library |
| [data](libtrackerboy/data.html)         | Data model                                     |
| [editing](libtrackerboy/editing.html)   | Utilities for editing pattern data             |
| [engine](libtrackerboy/engine.html)     | Song playback, or driver implementation        |
| [io](libtrackerboy/io.html)             | Module serialization/deserialization           |
| [ir](libtrackerboy/ir.html)             | Intermediate representation for import/export  |
| [notes](libtrackerboy/notes.html)       | Note lookup procs, note values                 |
| [text](libtrackerboy/text.html)         | Text conversion and parsing                    |
| [tracking](libtrackerboy/tracking.html) | Music tracking and pathing                     |
| [version](libtrackerboy/version.html)   | Version type and consts                        |

### Exporter modules

Modules that provide exporting to other formats are located in the exports
subfolder, `libtrackerboy/exports`.

| Module                                | Description                                    |
|---------------------------------------|------------------------------------------------|
| [wav](libtrackerboy/exports/wav.html) | Wav file exporter                              |

### Engine modules

These modules are mostly only used by the engine module, but can be imported
if low-level details of the engine are needed.

| Module                                                   | Description                   |
|----------------------------------------------------------|-------------------------------|
| [apucontrol](libtrackerboy/engine/apucontrol.html)       | APU Register writes           |
| [enginecontrol](libtrackerboy/engine/enginecontrol.html) | Core components of the Engine |
| [enginestate](libtrackerboy/engine/enginestate.html)     | Current state of the Engine   |
| [frequency](libtrackerboy/engine/frequency.html)         | Frequency effects             |

.. note:: Modules in the private folder (libtrackerboy/private) are private to
          the library and should not be imported by users of the library. 

## See also

* [Module file format specification](module-file-format-spec.html)

]##

import
  ./libtrackerboy/apu,
  ./libtrackerboy/common,
  ./libtrackerboy/data,
  ./libtrackerboy/editing,
  ./libtrackerboy/engine,
  ./libtrackerboy/io,
  ./libtrackerboy/notes,
  ./libtrackerboy/text,
  ./libtrackerboy/tracking,
  ./libtrackerboy/version,
  ./libtrackerboy/exports/wav


export 
  apu,
  common,
  data,
  editing,
  engine,
  io,
  notes,
  text,
  tracking,
  version,
  wav
