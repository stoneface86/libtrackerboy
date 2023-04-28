=================================
Module File Format Specifications
=================================

.. contents::

This page contains links to the file format specifications for TrackerBoy
Module files, or .tbm files. 

Specifications
==============

Current list of specifications, ordered from newest to oldest.

Major 1
-------
* TBM File Format Specification - Major Revision 1 (`HTML<tbm-spec-major-1.html>`_ `PDF<tbm-spec-major-1.pdf>`_)
  * **Revision C (1.1)**, introduced in Trackerboy v0.6.0
  * **Revision B (1.0)**, introduced in Trackerboy v0.5.0

Major 0
-------
* TBM File Format Specification - Major Revision 0 (`HTML<tbm-spec-major-0.html>`_ `PDF<tbm-spec-major-0.pdf>`_)
  * **Revision A (0.0)**, introduced in Trackerboy v0.2.0

Revision history
================

Changes to the file format are listed here, ordered from new to last. Revision
names use alphabet letters ie A, B, C, .., Z, AA, AB, .. onwards. Any change in
the major or minor version results in the letter being advanced.

.. note:: Revisions A, B and C use Trackerboy's versioning. Revisions D and
          later use libtrackerboy's versioning.

Revision C (1.1)
----------------

Introduced in Trackerboy v0.6.0.

* adds a new effect, Jxy, for setting the global volume
* added specification for instrument/waveform files (\*.tbi/\*.tbw)

Revision B (1.0)
----------------

Introduced in Trackerboy v0.5.0, adds multiple song support.

* file revision is now a major/minor set of numbers
* SONG, INST, and WAVE blocks each store a single song, instrument and
  waveform, respectively.
* The payload can now contain up to 256 songs
* Removed the INDX block
* Removed numberOfInstruments and numberOfWaveforms fields
* Added scount, icount and wcount fields at offset 124 (replacing the removed
  numberOf* fields). These fields contain the number of SONG, INST and WAVE
  blocks present in the payload. Note that only scount is biased (0 => 1).
* String encoding now specified for all strings. Header strings use ASCII,
  everything else uses UTF-8.
* `LString` now uses a 2-byte length instead of 1-byte
* Added a terminator to the format

Revision A (0.0)
----------------

First initial version, introduced in Trackerboy v0.2.0.
