/*
** Trackerboy - Gameboy / Gameboy Color music tracker
** Copyright (C) 2019-2020 stoneface86
**
** Permission is hereby granted, free of charge, to any person obtaining a copy
** of this software and associated documentation files (the "Software"), to deal
** in the Software without restriction, including without limitation the rights
** to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
** copies of the Software, and to permit persons to whom the Software is
** furnished to do so, subject to the following conditions:
**
** The above copyright notice and this permission notice shall be included in all
** copies or substantial portions of the Software.
**
** THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
** IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
** FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
** AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
** LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
** OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
** SOFTWARE.
**
*/

#pragma once

/*!
 * \file Module.hpp
 * \brief Module class definition
 */

#include "trackerboy/data/InfoStr.hpp"
#include "trackerboy/data/Table.hpp"
#include "trackerboy/data/SongList.hpp"
#include "trackerboy/Version.hpp"

#include <cstddef>
#include <istream>
#include <ostream>
#include <string>

namespace trackerboy {


/*!
 * \brief The Module class
 *
 * A module is a container for songs, instruments and waveforms. Each module
 * can store up to 256 songs, 64 instruments and 64 waveforms. Instruments and
 * Waveforms are shared between all songs.
 *
 * Modules can be saved to and loaded from files. This facility is provided by
 * the serialize and deserialize methods. The file format is documented
 * in the \ref file-format page.
 */
class Module {

public:

    // rule-of-zero

    /*!
     * \brief Default constructs the module
     *
     * The module is initialized with a single song and default settings
     */
    Module() noexcept;

    /*!
     * \brief Removes all data in the module
     *
     * All songs, instruments and waveforms are removed and the module is
     * re-initialized with 1 empty song.
     */
    void clear() noexcept;

    // header information

    /*!
     * \brief Gets artist information
     * \return an InfoStr reference with the artist's name
     *
     * By default this information is blank.
     */
    InfoStr const& artist() const noexcept;

    /*!
     * \brief Gets title information
     * \return an InfoStr reference with the title of the module
     *
     * By default this information is blank.
     */
    InfoStr const& title() const noexcept;

    /*!
     * \brief Gets copyright information
     * \return an InfoStr reference with the copyright of the module
     *
     * By default this information is blank.
     */
    InfoStr const& copyright() const noexcept;

    /*!
     * \brief Gets comment information
     * \return a string reference containing the module's comments
     *
     * By default this string is empty.
     */
    std::string const& comments() const noexcept;

    /*!
     * \brief Gets the version of trackerboy that created this module
     * \return the version
     *
     * For new modules, the version is set to 0.0.0 and should be overwritten
     * with the current version before serializing.
     */
    Version version() const noexcept;

    /*!
     * \brief Gets the file format major revision number
     * \return revision major of the file format (0-255)
     * \sa \ref major-rev in \ref file-format
     */
    int revisionMajor() const noexcept;

    /*!
     * \brief Gets the file format minor revision number
     * \return revision minor of the file format (0-255)
     * \sa \ref minor-rev in \ref file-format
     */
    int revisionMinor() const noexcept;

    /*!
     * \brief Gets the framerate the module should be played at
     * \return the framerate, in hertz
     * \sa system()
     */
    float framerate() const noexcept;

    /*!
     * \brief Gets the system the module is intended for
     * \return the module's system
     */
    System system() const noexcept;

    int customFramerate() const noexcept;

    SongList& songs() noexcept;
    SongList const& songs() const noexcept;

    WaveformTable& waveformTable() noexcept;
    WaveformTable const& waveformTable() const noexcept;

    InstrumentTable& instrumentTable() noexcept;
    InstrumentTable const& instrumentTable() const noexcept;

    // File I/O

    /*!
     * \brief Deserializes module data from the given input \a stream
     * \param stream an input stream containing the module data
     * \return FormatError::none on success
     *
     * This module's data is replaced with the data deserialized from the
     * given input \a stream. If the module was sucessfully deserialized,
     * then FormatError::none is returned. If an error occurred, the error
     * returned determines if there was a read error or an invalid data
     * format. On error the module may have been partially loaded from
     * the data.
     */
    FormatError deserialize(std::istream &stream) noexcept;

    FormatError serialize(std::ostream &stream) const noexcept;

    void setArtist(InfoStr const& artist) noexcept;

    void setTitle(InfoStr const& title) noexcept;

    void setCopyright(InfoStr const& copyright) noexcept;

    void setComments(std::string const& comments) noexcept;
    void setComments(std::string&& comments) noexcept;

    void setFramerate(System system) noexcept;

    void setFramerate(int rate);

    void setVersion(Version const& version) noexcept;

private:

    SongList mSongs;

    InstrumentTable mInstrumentTable;
    WaveformTable mWaveformTable;

    // header settings
    Version mVersion;
    int mRevisionMajor;
    int mRevisionMinor;
    // information about the module (same format as *.gbs)
    InfoStr mTitle;
    InfoStr mArtist;
    InfoStr mCopyright;

    // user comments/info about the module itself
    std::string mComments;

    System mSystem;
    int mCustomFramerate;
};


}
