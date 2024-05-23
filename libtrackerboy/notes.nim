##[

Types and procs for dealing with music notes and also note-to-frequency lookup.

]##

type
  NoteType* = enum
    ## Enum of the possible note kinds: 
    ## - tone: playable on channels 1, 2 and 3
    ## - noise: playable on channel 4
    ##
    tone
    noise

  ToneNote* = range[0..83]
    ## Note index range for a tone note (Tone notes are played on channels
    ## 1, 2 and 3). A tone note ranges from octaves 2 to 8, with C-2 being
    ## approx 64 Hz

  NoiseNote* = range[0..59]
    ## Note index range for a noise note (Noise notes are only played on
    ## channel 4). A noise note ranges from octaves 2 to 6, but the actual
    ## note played maps to a frequency setting in the noiseNoteTable.
  
  NoteRange* = range[0 .. high(ToneNote) + 1]
    ## Full note range, including special note indices. The full range is 7
    ## octaves (84 notes) with 1 special note index (cut), for a total of 85
    ## indices.
    ## 

  Octave* = range[2 .. 8]
    ## Available octave range of TrackerBoy notes
    ## 
  
  Letter* = range[0 .. 11]
    ## Note letter as an integer range. 0 is C, 1 is C#, ... 11 is B
    ## 
  
  NoteIndex* = uint8
    ## Index type that refers to a note in a lookup table.
    ##

  NotePair* = object
    ## Note represented as a pair of a [Letter] and [Octave].
    ##
    letter*: Letter
    octave*: Octave

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
    ##

  C*      = Letter(0)
    ## Note of C at any octave.
    ##
  CSharp* = Letter(1)
    ## Note of C#/Db at any octave.
    ##
  D*      = Letter(2)
    ## Note of D at any octave.
    ##
  DSharp* = Letter(3)
    ## Note of D#/Eb at any octave.
    ##
  E*      = Letter(4)
    ## Note of E at any octave.
    ##
  F*      = Letter(5)
    ## Note of F at any octave.
    ##
  FSharp* = Letter(6)
    ## Note of F#/Gb at any octave.
    ##
  G*      = Letter(7)
    ## Note of G at any octave.
    ##
  GSharp* = Letter(8)
    ## Note of G#/Ab at any octave.
    ##
  A*      = Letter(9)
    ## Note of A at any octave.
    ##
  ASharp* = Letter(10)
    ## Note of A#/Bb at any octave.
    ## 
  B*      = Letter(11)
    ## Note of B at any octave.
    ##

  DFlat* = CSharp
    ## Db, same as [CSharp].
    ##
  EFlat* = DSharp
    ## Eb, same as [DSharp].
    ##
  GFlat* = FSharp
    ## Gb, Same as [FSharp].
    ##
  AFlat* = GSharp
    ## Ab, Same as [GSharp].
    ##
  BFlat* = ASharp
    ## Bb, Same as [ASharp].
    ##

template lookup(table: untyped; note: Natural): auto =
  table[clamp(note, low(table), high(table))]

{. push raises: [] .}

func lookupToneNote*(note: Natural): uint16 =
  ## Lookup the frequency value for the given note index. `note` is clamped
  ## within the bounds of [ToneNote].
  ##
  lookup(toneNoteTable, note)

func lookupNoiseNote*(note: Natural): uint8 =
  ## Lookup the noise value or NR43 setting for the given note index. `note` is
  ## clamped within the bounds of [NoiseNote].
  ##
  lookup(noiseNoteTable, note)

func toNote*(letter: Letter; octave: Octave): NoteIndex =
  ## Convert a note at a given octave to a note index.
  ##
  result = NoteIndex(((octave.int - 2) * 12) + letter)

func toNote*(p: NotePair): NoteIndex {.inline.} =
  ## Convert the note pair to a note index.
  ##
  result = toNote(p.letter, p.octave)

func toNote*(i: int): NoteIndex {.inline.} =
  ## Convert an integer index to a note index, clamping if necessary.
  ##
  result = NoteIndex(clamp(i, NoteRange.low, NoteRange.high))

func notePair*(letter: Letter; octave: Octave): NotePair =
  ## Construct a note pair with the given components.
  ##
  result = NotePair(letter: letter, octave: octave)

func toPair*(index: NoteIndex): NotePair =
  ## Convert a note index into a letter and octave pairing.
  ##
  result = notePair(Letter(int(index) mod 12), Octave((int(index) div 12) + 2))

{. pop .}

