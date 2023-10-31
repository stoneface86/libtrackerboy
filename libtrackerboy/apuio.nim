##[

Apu I/O access. Provides an ApuIo concept for reading and writing to APU I/O
registers.

]##

import
  ./private/hardware

type
  ApuRegister* = enum
    ## Enum for Apu register addresses.
    ##
    # CH1 - Square 1 ------------------------------------------------------
    ar10 = rNR10    ## NR10 -PPP NSSS - CH1 sweep period, negate, shift
    ar11 = rNR11    ## NR11 DDLL LLLL - CH1 duty, length
    ar12 = rNR12    ## NR12 VVVV APPP - CH1 envelope volume, mode, period
    ar13 = rNR13    ## NR13 FFFF FFFF - CH1 frequency LSB
    ar14 = rNR14    ## NR14 TL-- -FFF - CH1 trigger, length enable, frequency MSB
    # CH2 - Square 2 ------------------------------------------------------
    ar21 = rNR21    ## NR21 DDLL LLLL - CH2 duty, length
    ar22 = rNR22    ## NR22 VVVV APPP - CH2 envelope volume, mode, period
    ar23 = rNR23    ## NR23 FFFF FFFF - CH2 frequency LSB
    ar24 = rNR24    ## NR24 TL-- -FFF - CH2 trigger, length enable, frequency MSB
    # CH3 - Wave ----------------------------------------------------------
    ar30 = rNR30    ## NR30 E--- ---- - CH3 DAC enable
    ar31 = rNR31    ## NR31 LLLL LLLL - CH3 length
    ar32 = rNR32    ## NR32 -VV- ---- - CH3 wave volume
    ar33 = rNR33    ## NR33 FFFF FFFF - CH3 frequency LSB
    ar34 = rNR34    ## NR34 TL-- -FFF - CH3 trigger, length enable, frequency MSB
    # CH4 - Noise ---------------------------------------------------------
    ar41 = rNR41    ## NR41 --LL LLLL - CH4 length
    ar42 = rNR42    ## NR42 VVVV APPP - CH4 envelope volume, mode, period
    ar43 = rNR43    ## NR43 SSSS WDDD - CH4 clock shift, width, divisor mode
    ar44 = rNR44    ## NR44 TL-- ---- - CH4 trigger, length enable
    # Control/Status ------------------------------------------------------
    ar50 = rNR50    ## NR50 ALLL BRRR - VIN enable (A/B), master volume (L/R)
    ar51 = rNR51    ## NR51 4321 4321 - Channel terminal enables
    ar52 = rNR52    ## NR52 P--- 4321 - Power control, channel length status
    # Wave RAM
    arWaveram = rWAVERAM    ## CH3 Wave RAM, 0xFF30 to 0xFF3F

  ApuIo* = concept var a
    ## Concept for a generic Apu emulator that provides I/O access procs.
    ##
    readRegister(a, uint8) is uint8
    writeRegister(a, uint8, uint8)

template toAddress*(reg: ApuRegister): uint8 = reg.ord.uint8
  ## Convert the register to its address. This just converts the result of
  ## ord to an uint8.
  ##

# These don't work with the ApuIo concept, "too nested for type matching"

# template readRegister*(apu: ApuIo, reg: ApuRegister): uint8 =
#     ## Shortcut for the `ApuIo`'s `readRegister` proc by using an ApuRegister
#     ## enum instead of an address.
#     apu.readRegister(reg.toAddress)

# template writeRegister*(apu: var ApuIo, reg: ApuRegister, val: uint8) =
#     ## Shortcut for the ApuIo's `writeRegister` proc by using an ApuRegister
#     ## enum instead of an address
#     apu.writeRegister(reg.toAddress, val)
