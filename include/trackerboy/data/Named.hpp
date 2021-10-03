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
 * \file Named.hpp
 * \brief Named class definition
 */

#include <string>

namespace trackerboy {

/*!
 * \brief Base class providing a name getter/setter
 *
 * This class serves as a base class providing a simple std::string
 * name getter/setter.
 */
class Named {

public:
    Named() = default;

    /*!
     * \brief accessor for the name.
     * \return a const reference to this object's name.
     */
    std::string const& name() const;

    /*!
     * \brief Sets the name from the given string.
     * \param name the name to set
     */
    void setName(std::string const& name);

    /*!
     * \brief Sets the name by moving the given string.
     * \param name the name to move
     */
    void setName(std::string&& name);

private:
    std::string mName;
};

}
