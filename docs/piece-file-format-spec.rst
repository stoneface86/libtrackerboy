========================
Module Piece File Format
========================

.. contents::

Introduction
============

This document is a formal specification of the file format used in Trackerboy
module piece files, or \*.tbi, \*.tbs and \*.tbw files.

Piece files contain a single instrument (\*.tbi), song (\*.tbs), or waveform
(\*.tbw) that can be imported into or exported from an existing module. Piece
files allow users to share parts of their module with others, for easier reuse
and collaboration.

For the module file format see `here<module-file-format-spec.html>`_.

The libtrackerboy library provides a reference implementation for serializing
and deserialing module pieces with this format. See the
`io module<libtrackerboy/io.html>`_ for more documentation.

Structure
=========

A piece file consists of a header followed by a payload. The payload is a
single INST, SONG or WAVE block. A terminator is not used since there is only
one block present in the payload.

Header
======

The figure below defines the Header structure for all piece files. These files
use a reduced version of the header used in the module file format. The fields
are exactly the same as the module format, see that specification for more info.

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
     | m. rev   | n. rev   |
 28  +----------+----------+
```

Payload
=======

The payload is a single INST block for \*.tbi files, a single SONG block for
\*.tbs files or a single WAVE block for \*.tbw files.

The format of these blocks are the same as the ones used in the module file
format except for one key detail: the id is omitted for INST and WAVE blocks.

.. note:: INST and WAVE blocks will be 1 byte less than their module
          counterpart.

Revision history
================

Module pieces share the `same history<module-file-format-spec.html#revision-history>`_ as Modules.
