
# similar to hardware.inc
# gameboy hardware constants

const

    gbClockrate* = 4194304
    gbVblank* = 59.7

    # CH1 - Square 1 --------------------------------------------------------
    rNR10* = 0x10u8
    rNR11* = 0x11u8
    rNR12* = 0x12u8
    rNR13* = 0x13u8
    rNR14* = 0x14u8
    # CH2 - Square 2 --------------------------------------------------------
    rNR21* = 0x16u8
    rNR22* = 0x17u8
    rNR23* = 0x18u8
    rNR24* = 0x19u8
    # CH3 - Wave ------------------------------------------------------------
    rNR30* = 0x1Au8
    rNR31* = 0x1Bu8
    rNR32* = 0x1Cu8
    rNR33* = 0x1Du8
    rNR34* = 0x1Eu8
    # CH4 - Noise -----------------------------------------------------------
    rNR41* = 0x20u8
    rNR42* = 0x21u8
    rNR43* = 0x22u8
    rNR44* = 0x23u8
    # Control/Status --------------------------------------------------------
    rNR50* = 0x24u8
    rNR51* = 0x25u8
    rNR52* = 0x26u8
    # Wave RAM
    rWAVERAM* = 0x30u8
