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
 * \file IApuIo.hpp
 * \brief IApuIo interface definition
 */

#include <cstdint>

namespace trackerboy {

/*!
 * \brief interface for Apu I/O operations
 *
 * Provides an interface for reading and writing to APU registers.
 */
class IApuIo {

public:

    /*!
     * \brief enumeration for register addresses.
     *
     * CH1 registers:
     * | Name | Address | Format      | Details                               |
     * |------|---------|-------------|---------------------------------------|
     * | NR10 |  0xFF10 | `-PPP NSSS` | sweep period, negate, shift           |
     * | NR11 |  0xFF11 | `DDLL LLLL` | duty, length                          |
     * | NR12 |  0xFF12 | `VVVV APPP` | envelope volume, mode, period         |
     * | NR13 |  0xFF13 | `FFFF FFFF` | Frequency LSB                         |
     * | NR14 |  0xFF14 | `TL-- -FFF` | Trigger, length enable, frequency MSB |
     *
     * CH2 registers:
     * | Name | Address | Format      | Details                               |
     * |------|---------|-------------|---------------------------------------|
     * | NR20 |  0xFF15 | `---- ----` | unused                                |
     * | NR21 |  0xFF16 | `DDLL LLLL` | duty, length                          |
     * | NR22 |  0xFF17 | `VVVV APPP` | envelope volume, mode, period         |
     * | NR23 |  0xFF18 | `FFFF FFFF` | Frequency LSB                         |
     * | NR24 |  0xFF19 | `TL-- -FFF` | Trigger, length enable, frequency MSB |
     *
     * CH3 registers:
     * | Name | Address | Format      | Details                               |
     * |------|---------|-------------|---------------------------------------|
     * | NR30 |  0xFF1A | `E--- ----` | DAC Power                             |
     * | NR31 |  0xFF1B | `LLLL LLLL` | Length                                |
     * | NR32 |  0xFF1C | `-VV- ----` | wave volume                           |
     * | NR33 |  0xFF1D | `FFFF FFFF` | Frequency LSB                         |
     * | NR34 |  0xFF1E | `TL-- -FFF` | Trigger, length enable, frequency MSB |
     *
     * CH4 registers:
     * | Name | Address | Format      | Details                               |
     * |------|---------|-------------|---------------------------------------|
     * | NR40 |  0xFF1F | `---- ----` | unused                                |
     * | NR41 |  0xFF20 | `--LL LLLL` | length                                |
     * | NR42 |  0xFF21 | `VVVV APPP` | envelope volume, mode, period         |
     * | NR43 |  0xFF22 | `SSSS WDDD` | clock shift, width, divisor mode      |
     * | NR44 |  0xFF23 | `TL-- ----` | Trigger, length enable                |
     *
     * Sound control registers:
     * | Name | Address | Format      | Details                               |
     * |------|---------|-------------|---------------------------------------|
     * | NR50 |  0xFF24 | `ALLL BRRR` | VIN enable (A/B), master volume (L/R) |
     * | NR51 |  0xFF25 | `4321 4321` | Channel terminal enables              |
     * | NR52 |  0xFF26 | `P--- 4321` | Power control, channel length status  |
     *
     * Waveram: 0xFF30 - 0xFF3F
     *
     */
    enum Reg {
        // CH1 - Square 1 --------------------------------------------------------
        REG_NR10 = 0x10,
        REG_NR11 = 0x11,
        REG_NR12 = 0x12,
        REG_NR13 = 0x13,
        REG_NR14 = 0x14,
        // CH2 - Square 2 --------------------------------------------------------
        REG_UNUSED1 = 0x15,
        REG_NR21 = 0x16,
        REG_NR22 = 0x17,
        REG_NR23 = 0x18,
        REG_NR24 = 0x19,
        // CH3 - Wave ------------------------------------------------------------
        REG_NR30 = 0x1A,
        REG_NR31 = 0x1B,
        REG_NR32 = 0x1C,
        REG_NR33 = 0x1D,
        REG_NR34 = 0x1E,
        // CH4 - Noise -----------------------------------------------------------
        REG_UNUSED2 = 0x1F,
        REG_NR41 = 0x20,
        REG_NR42 = 0x21,
        REG_NR43 = 0x22,
        REG_NR44 = 0x23,
        // Control/Status --------------------------------------------------------
        REG_NR50 = 0x24,
        REG_NR51 = 0x25,
        REG_NR52 = 0x26,
        // Wave RAM
        REG_WAVERAM = 0x30
    };

    /*!
     * \brief Performs an APU register read
     * \param reg the register to read
     * \return the value read from the register
     *
     * Note that some registers are write-only and attempting to read these
     * registers will result in all bits being read back as 1.
     *
     * For any unknown register, 0 is returned.
     */
    virtual uint8_t readRegister(uint8_t reg) = 0;

    /*!
     * \brief Performs an APU register write
     * \param reg the register to write to
     * \param value the value to write
     *
     * The write is ignored for any unknown register, and for read-only registers.
     */
    virtual void writeRegister(uint8_t reg, uint8_t value) = 0;

};


}
