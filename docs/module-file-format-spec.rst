==================
Module File Format
==================

.. contents::

Introduction
============

This document is a formal specification of the file format for Trackerboy
module files, or \*.tbm files. This document is for the current revision, or
revision 1.1. See the revision history for previous revisions.

A Module file is a serialized form of the `Module<libtrackerboy/data.html#Module>`_ object.

For the piece file format see `here<piece-file-format-spec.html>`_.

The libtrackerboy library provides a reference implementation for serializing
and deserialing module files with this format. See the
`io module<libtrackerboy/io.html>`_ for more documentation.

.. note:: All multi-byte fields in this specification are stored in
          little-endian byte order.

Definitions
===========

- **Order** - Song order data, a list of OrderRows that determine each pattern
              in the song.
- **OrderRow** - A track id assignment for each channel. Determines the tracks
                 which make a pattern.
- **Pattern** - A collection of Tracks, one for each channel.
- **Track** - Song data for a single channel. A Track is a list of TrackRows.

Basic Types
-----------

Below are basic data types used throughout the format

============  ==============  =======================================================================
Type name     Size (bytes)    Description
============  ==============  =======================================================================
Uint8         1               Unsigned 8-bit integer (0-255)                                       
BiasedUint8   1               Unsigned 8-bit integer, biased form (1-256)                          
Bool          1               Boolean as an uint8 (0 for false, nonzero for true)                  
Uint16        2               Unsigned 16-bit integer, in little endian (0-65536)                  
Uint32        4               Unsigned 32-bit integer, in little endian                            
LString       varies          Length-prefixed UTF-8 string, string data prefixed by a Uint16 length
============  ==============  =======================================================================

Error codes
-----------

Below is a list of error codes possible when deserialing/serializing a module
file. After processing a file, one of these error codes, or Format Result (fr),
is given.

===================  ====  =============================================================================
Identifier           Code  Description
===================  ====  =============================================================================
frNone               0     No error, format is acceptable
frInvalidSignature   1     File has an invalid signature
frInvalidRevision    2     File has an unrecognize revision, possibly from a newer version of the format
frCannotUpgrade      3     An older revision file could not be upgraded to the current revision
frInvalidSize        4     A payload block was incorrectly sized
frInvalidCount       5     The icount and/or wcount in the header was too big
frInvalidBlock       6     An unknown identifier was used in a payload block
frInvalidChannel     7     The format contains an invalid channel in a payload block
frInvalidSpeed       8     The format contains an invalid speed in a SONG block
frInvalidRowCount    9     A TrackFormat's rows field exceeds the Song's track size
frInvalidRowNumber   10    A RowFormat's rowno field exceeds the Song's track size
frInvalidId          11    An INST or WAVE block contains an invalid id
frDuplicatedId       12    Two INST blocks or two WAVE blocks have the same id
frInvalidTerminator  13    The file has an invalid terminator
frReadError          14    An read error occurred during processing
frWriteError         15    A write error occurred during processing
===================  ====  =============================================================================

Structure
=========

A Trackerboy module consists of a Header, a Payload and a Terminator.

```
   +----------------+-----------------------------------------+------------+
   |                |                                         |            |
   | Header         | Payload                                 | Terminator |
   | 160 bytes      | size varies                             | 12 bytes   |
   |                |                                         |            |
   +----------------+-----------------------------------------+------------+
  +0              +160                                                      EOF
```

Header
======

The figure below defines the Header structure used in all file types. All
multi-byte fields are stored in little-endian. The size of the header is a
fixed 160 bytes, with any unused space marked as reserved. Reserved fields can
be utilized for future revisions of the format. Reserved fields should be set
to zero, but this is not enforced.

The layout of the header depends on the header revision, located in offset 24.
The current revision of the header is shown below.

```
      +0         +1         +2        +3
  0   +-------------------------------------------+
      |                                           |
      | signature ( TRACKERBOY )                  |
      |                                           |
  12  +-------------------------------------------+
      | version major                             |
  16  +-------------------------------------------+
      | version minor                             |
  20  +-------------------------------------------+
      | version patch                             |
  24  +----------+----------+---------------------+
      | m. rev   | n. rev   | reserved            |
  28  +----------+----------+---------------------+
      |                                           |
      |                                           |
      |                                           |
      | title                                     |
      |                                           |
      |                                           |
      |                                           |
      |                                           |
  60  +-------------------------------------------+
      |                                           |
      |                                           |
      |                                           |
      | artist                                    |
      |                                           |
      |                                           |
      |                                           |
      |                                           |
  92  +-------------------------------------------|
      |                                           |
      |                                           |
      |                                           |
      | copyright                                 |
      |                                           |
      |                                           |
      |                                           |
      |                                           |
  124 +-------------------------------------------+
      | icount   | scount   | wcount   | system   |
  128 +---------------------+----------+----------+
      | customFramerate     |                     |
      +---------------------+                     |
      |                                           |
      |                                           |
      |                                           |
      | reserved                                  |
      |                                           |
      |                                           |
      |                                           |
      |                                           |
  160 +-------------------------------------------+
```

Signature
---------

Every trackerboy file begins with this signature:

`\0TRACKERBOY\0` 

in order to identify the file as a trackerboy file.

Version (major, minor, patch)
-----------------------------

Version information is stored as three 4-byte words. This information
determines which version of trackerboy that created the file. Versioning is
maintained by keeping a major and minor version, followed by a patch number.
For example, if the trackerboy version is v1.0.2, then the header's version
fields will contain `0x1` `0x0` and `0x2` for major, minor and patch,
respectively.

Major revision (m. rev)
-----------------------

This version number indicates a breaking change for the file format. Starts
at 0 and is incremented whenever the layout of the header or payload changes.
Trackerboy will not attempt to read modules with a newer major version, but can
attempt to read older versions (backwards-compatible).

Examples of breaking changes:
- Modifying the layout of the Header structure
- Adding/removing blocks to the payload
- Modifying the format of a payload block

Minor revision (n. rev)
-----------------------

This version number indicates a change in the format that is forward-compatible
with older versions. Changes such as utilizing a reserved field in the header.

.. note:: Trackerboy can read any module file as long as its major revision is
          less than or equal to the current revision. Saving always uses the
          current revision, so saving an older major version is a one-way
          upgrade.

Author information (title, artist, copyright)
---------------------------------------------

These fields in the header are fixed 32 byte strings. Assume ASCII encoding.
Any unused characters in the string should be set to 0 or `\0`. Since these
strings are fixed, null-termination is not needed.

.. note:: The size and naming of these strings are identical to the ones in
          \*.gbs file format. This is intentional, as exporting to gbs is a
          planned feature.

icount, scount and wcount
-------------------------

- `icount` - **i**nstrument count
- `scount` - **s**ong count
- `wcount` - **w**aveform count

These counter fields determine the number of INST, SONG and WAVE blocks present
in the payload, respectively. `icount` and `wcount` can range from 0-64 and is
unbiased. `scount` can range from 0-255 and is biased (a value of 0 means there
is 1 SONG block). 

System
------

The system field determines which Game Boy model this module is for. Since the
driver is typically updated every vblank, the system field determines the
framerate, tick rate or vblank interval for the driver. The available choices
are listed in the following table:

============  =====  ===========  =========
Identifier    Value  System name  Tick rate
============  =====  ===========  =========
systemDmg     0      DMG          59.7 Hz
systemSgb     1      SGB          61.1 Hz
systemCustom  2      N/A          varies
============  =====  ===========  =========

If the system is `systemCustom`, then a custom tick rate is used instead of the
system's vblank. The custom tick rate is stored in the `customFramerate` field
of the header.

By default the DMG system, `systemDmg`, is selected.

Payload
=======

The payload is located right after the header (offset 160). It is a variable
number of "blocks" or tagged data with a size.

Blocks
------

A block in the payload contains three parts: the id, the length and the data.
The format of the block is shown below:

======  ======  ===========
Offset  Size    Description
======  ======  ===========
0       4       Id
4       4       Length
8       Length  Data
======  ======  ===========

Block types
-----------

Each block has an identifier, which determines the type of data present in the block.
The table below lists all recognized identifiers in the payload.

==========  ==========  ==================================
Identifier  Uint32      Description
==========  ==========  ==================================
"COMM"      0x4D4D4F43  User set comment data for a module
"SONG"      0x474E4F53  Contains a single song
"INST"      0x54534E49  Contains a single instrument
"WAVE"      0x45564157  Contains a single waveform
==========  ==========  ==================================

Block ordering
--------------

Blocks are stored categorically by type in the following order:

=====  ==========  =====
Order  Identifier  Count
=====  ==========  =====
1      COMM        1
2      SONG        1-256
3      INST        0-64
4      WAVE        0-64
=====  ==========  =====

COMM block format
-----------------

The COMM block just contains a UTF-8 string the is the user's comment data. The
string is not null-terminated since the length of the string is the length of
the block. If the user has no comment set, then this block is empty
(length = 0).

SONG block format
-----------------

The SONG block contains the data for a single song. Songs are stored in the
same order as they were in the module's song list. The first song block is song
#0 and so on.

Song data is composed of the following, in this order:
1. Name, as an `LString`
2. A `SongFormat` record
3. The song order, as an array of `OrderRow`
4. The track data, as a sequence of `TrackFormat` and `RowFormat` records

INST block format
-----------------

WAVE block format
-----------------

Terminator
==========

Following the payload is the terminator, which signifies the end of the file.
The terminator is the signature, reversed:

```
"\0YOBREKCART\0"
```

There should be no data after this terminator. Any data after the terminator
will be ignored.

Revision history
================

Changes to the file format are listed here, ordered from new to last.

Revision C (1.1)
----------------

Introduced in v0.6.0
 - adds a new effect, Jxy, for setting the global volume
 - added specification for instrument/waveform files (\*.tbi/\*.tbw)

Revision B (1.0)
----------------

Introduced in v0.5.0, adds multiple song support.
 - file revision is now a major/minor set of numbers
 - SONG, INST, and WAVE blocks each store a single song, instrument and
   waveform, respectively.
 - The payload can now contain up to 256 songs
 - Removed the INDX block
 - Removed numberOfInstruments and numberOfWaveforms fields
 - Added scount, icount and wcount fields at offset 124 (replacing the removed
   numberOf* fields). These fields contain the number of SONG, INST and WAVE
   blocks present in the payload. Note that only scount is biased (0 => 1).
 - String encoding now specified for all strings. Header strings use ASCII,
   everything else uses UTF-8.
 - `lstring` now uses a 2-byte length instead of 1-byte
 - Added a terminator to the format

Revision A (0.0)
----------------

First initial version, introduced in v0.2.0.
