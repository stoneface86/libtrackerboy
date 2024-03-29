##[

Note lookup procs. Contains lookup procs for the two types of notes in
Trackerboy, tone notes and noise notes.

]##

type
  ToneNote* = range[0..83]
    ## Note index range for a tone note (Tone notes are played on channels
    ## 1, 2 and 3). A tone note ranges from octaves 2 to 8, with C-2 being
    ## approx 64 Hz

  NoiseNote* = range[0..59]
    ## Note index range for a noise note (Noise notes are only played on
    ## channel 4). A noise note ranges from octaves 2 to 6, but the actual
    ## note played maps to a frequency setting in the noiseNoteTable.

const
  toneNoteTable: array[ToneNote, uint16] = [
  #    C        Db      D     Eb      E      F     Gb      G     Ab      A     Bb     B
    0x02Cu16, 0x09D, 0x107, 0x16B, 0x1C9, 0x223, 0x277, 0x2C7, 0x312, 0x358, 0x39B, 0x3DA, # 2
    0x416,    0x44E, 0x483, 0x4B5, 0x4E5, 0x511, 0x53B, 0x563, 0x589, 0x5AC, 0x5CE, 0x5ED, # 3
    0x60B,    0x627, 0x642, 0x65B, 0x672, 0x689, 0x69E, 0x6B2, 0x6C4, 0x6D6, 0x6E7, 0x6F7, # 4
    0x706,    0x714, 0x721, 0x72D, 0x739, 0x744, 0x74F, 0x759, 0x762, 0x76B, 0x773, 0x77B, # 5
    0x783,    0x78A, 0x790, 0x797, 0x79D, 0x7A2, 0x7A7, 0x7AC, 0x7B1, 0x7B6, 0x7BA, 0x7BE, # 6
    0x7C1,    0x7C5, 0x7C8, 0x7CB, 0x7CE, 0x7D1, 0x7D4, 0x7D6, 0x7D9, 0x7DB, 0x7DD, 0x7DF, # 7
    0x7E1,    0x7E2, 0x7E4, 0x7E6, 0x7E7, 0x7E9, 0x7EA, 0x7EB, 0x7EC, 0x7ED, 0x7EE, 0x7EF  # 8
  ]

  noiseNoteTable: array[NoiseNote, uint8] = [
  #   C       Db      D     Eb      E      F     Gb      G     Ab      A     Bb      B
    0xD7u8,  0xD6,  0xD5,  0xD4,  0xC7,  0xC6,  0xC5,  0xC4,  0xB7,  0xB6,  0xB5,  0xB4,   # 2
    0xA7,    0xA6,  0xA5,  0xA4,  0x97,  0x96,  0x95,  0x94,  0x87,  0x86,  0x85,  0x84,   # 3
    0x77,    0x76,  0x75,  0x74,  0x67,  0x66,  0x65,  0x64,  0x57,  0x56,  0x55,  0x54,   # 4
    0x47,    0x46,  0x45,  0x44,  0x37,  0x36,  0x35,  0x34,  0x27,  0x26,  0x25,  0x24,   # 5
    0x17,    0x16,  0x15,  0x14,  0x07,  0x06,  0x05,  0x04,  0x03,  0x02,  0x01,  0x00    # 6
  ]

  noteCut* = (high(ToneNote) + 1).uint8
    ## Special note index for a note cut. When used the channel will be
    ## silenced by disabling the DAC.

template lookup(table: untyped; note: Natural): auto =
  table[clamp(note, low(table), high(table))]

{. push raises: [] .}

func lookupToneNote*(note: Natural): uint16 =
  lookup(toneNoteTable, note)

func lookupNoiseNote*(note: Natural): uint8 =
  lookup(noiseNoteTable, note)

func note*(str: string): uint8 {.compileTime.} =
  ## Compile time function for converting a string literal to a note index
  ## Notes must range from C-2 to B-8, sharp and flat accidentals can be used.
  ## ie `note("c-2") => 0`, `"D#3".note => 15`
  # C C# D D# E F F# G G# A A# B
  # C Db D Eb E F Gb G Ab A Bb B
  # 0 1  2 3  4 5 6  7 8  9 10 11
  doAssert str.len == 3
  case str[0]:
  of 'C', 'c':
    result = 0
  of 'D', 'd':
    result = 2
  of 'E', 'e':
    result = 4
  of 'F', 'f':
    result = 5
  of 'G', 'g':
    result = 7
  of 'A', 'a':
    result = 9
  of 'B', 'b':
    result = 11
  of '-':
    return noteCut
  else:
    doAssert false, "invalid note"
  if str[1] == '#':
    inc result
  elif str[1] == 'b':
    dec result
  else:
    doAssert str[1] == '-', "invalid note"
  let octave = (str[2].ord - '2'.ord)
  doAssert octave >= 0 and octave <= 6, "invalid octave"
  result += (octave * 12).uint8

{. pop .}

static:
  assert note("c-2") == 0
  assert note("---") == noteCut
