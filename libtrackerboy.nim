##[

libtrackerboy is a utility library used by trackerboy, a Game Boy tracker. This
library provides the core functionality needed by the UI, and is also known as
the backend.

Looking for trackerboy?
- The repository for the desktop application is `here<https://github.com/stoneface86/trackerboy>`_.
- Click `here<https://trackerboy.org/manual>`_ for the user manual.

This library handles:
- Game Boy APU emulation and sound synthesis
- Manipulating module data
- Module playback and exports
- Reading/Writing module files

Usage
=====

```nim
import libtrackerboy                   # import everything
import libtrackerboy/[data, io]        # import specific modules (Recommended)
```

Available modules:
------------------

======================================  ==============================================
Module                                  Description
======================================  ==============================================
`apu<libtrackerboy/apu.html>`_          Game Boy APU emulation
`apuio<libtrackerboy/apuio.html>`_      APU I/O access, provides ApuIo concept
`common<libtrackerboy/common.html>`_    Common types/procs used throughout the library
`data<libtrackerboy/data.html>`_        Data model
`editing<libtrackerboy/editing.html>`_  Utilities for editing pattern data
`engine<libtrackerboy/engine.html>`_    Song playback, or driver implementation
`io<libtrackerboy/io.html>`_            Module serialization/deserialization
`notes<libtrackerboy/notes.html>`_      Note lookup procs, note values
`version<libtrackerboy/version.html>`_  Version type and consts
======================================  ==============================================

.. note:: Modules in the private folder (libtrackerboy/private) are private to
          the library and should not be imported by users of the library. 

See also
========

- `Module file format specification<module-file-format-spec.html>`_
- `Module piece file format specification<piece-file-format-spec.html>`_
- `Trackerboy compiler guide<tbc.html>`_

]##

import libtrackerboy/[
    apu,
    common,
    data,
    editing,
    engine,
    io,
    notes,
    version
]
export apu, common, data, editing, engine, io, notes, version
