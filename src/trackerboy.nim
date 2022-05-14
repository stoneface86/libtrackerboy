##[

libtrackerboy is a utility library used by Trackerboy, a Game Boy tracker. This
library provides the core functionality needed by the UI, and is also known as
the backend.

Looking for Trackerboy?
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
import trackerboy                   # import everything
import trackerboy/[data, io]        # import specific modules (Recommended)
```

Available modules:
------------------

===================================  ==============================================
Module                               Description
===================================  ==============================================
`apu<trackerboy/apu.html>`_          Game Boy APU emulation
`common<trackerboy/common.html>`_    Common types/procs used throughout the library
`data<trackerboy/data.html>`_        Data model
`editing<trackerboy/editing.html>`_  Utilities for editing pattern data
`engine<trackerboy/engine.html>`_    Song playback, or driver implementation
`io<trackerboy/io.html>`_            Module serialization/deserialization
`notes<trackerboy/notes.html>`_      Note lookup procs, note values
`version<trackerboy/version.html>`_  Version type and consts
===================================  ==============================================

.. note:: Modules in the private folder (trackerboy/private) are private to
          the library and should not be imported by users of the library. 

See also
========

- `Module file format specification<module-file-format-spec.html>`_
- `Module piece file format specification<piece-file-format-spec.html>`_

]##

import trackerboy/[
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
