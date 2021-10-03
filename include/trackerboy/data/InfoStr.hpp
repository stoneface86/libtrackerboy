/*
** Trackerboy - Gameboy / Gameboy Color music tracker
** Copyright (C) 2019-2021 stoneface86
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
 * \file InfoStr.hpp
 * \brief InfoStr class definition
 */

#include <array>
#include <string>

namespace trackerboy {

/*!
 * \brief 32 byte character information string
 *
 * This is a fixed length string up to 32 characters. Wrapper for a
 * 32 element char array with utility std::string conversion methods.
 *
 * The size of this class is guaranteed to be 32 bytes.
 */
class InfoStr : public std::array<char, 32> {

public:
    InfoStr() = default;

    /*!
     * \brief implicit constructor from a std::string reference
     * \param str The string to copy
     * The string is intialized with the contents of the given str. Only
     * the first 32 characters in the given string are copied if the
     * string is larger than 32 characters.
     */
    InfoStr(std::string const& str) noexcept;

    /*!
     * \brief implicit constructor from a c-style string
     * \param str the string to copy
     * The string is initialized with the contents of the given string. Same
     * as the std::string overload, only the first 32 characters in the
     * given string are copied.
     */
    InfoStr(const char *str) noexcept;

    /*!
     * \brief assignment operator for a std::string
     * \param str the string to assign
     * \return a reference to this
     * \sa InfoStr(std::string const& str)
     */
    InfoStr& operator=(std::string const& str) noexcept;

    /*!
     * \brief assignment operator for a c-style string
     * \param str the string to assign
     * \return a reference to this
     * \sa InfoStr(const char *str)
     */
    InfoStr& operator=(const char *str) noexcept;

    /*!
     * \brief fills the string with '\0'
     * Shortcut for calling fill('\0')
     */
    void clear() noexcept;

    /*!
     * \brief Converts the character array to a std::string
     * \return a std::string version of this class
     */
    std::string toString() const noexcept;

    /*!
     * \brief Gets the length of the string in characters
     * \return The length
     * Note that the length of the string is always <= size()
     */
    size_t length() const noexcept;

};

}
