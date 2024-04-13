##[

.. include:: warning.rst

]##

# Utility module for writing RGBASM dilect assembly.
# Mostly just procs for encoding data in assembly source

import std/[strutils]

const
  indentation = "    "  # 4-space tabs
  lineLength = 80       # try to fit output to 80 columns per line
  commaDelim = ", "     # arguments to a command/instruction are comma delimited

type
  AsmByte* = uint8
    ## SM83 Byte datatype, 1 byte integer
    ##
  AsmWord* = uint16
    ## SM83 Word datatype, 2 byte integer
    ##
  AsmLong* = uint32
    ## SM83 Long word datatype, 4 byte integer

  SomeAsmInt* = AsmByte | AsmWord | AsmLong
    ## Type class of all SM83 integer types
    ##

  DataDirectives = enum
    dDb = "DB"  # Data Byte (1 byte)
    dDw = "DW"  # Data Word (2 bytes)
    dDl = "DL"  # Data Long (4 bytes)

  DataBuilder = object
    ## Utility object for building a command call with multiple arguments,
    ## wrapping to fit within lineLength.
    ##
    output: string
    newline: string
    itemsOnLine: int
    itemsPerLine: int

func getDataDirective(T: typedesc[SomeAsmInt]
                     ): DataDirectives {.compileTime.} =
  ## Get the data directive for the given type T
  ##
  when T is AsmByte: dDb
  elif T is AsmWord: dDw
  else: dDl

func asmDirective(dirName: string): string =
  ## Start an RGBASM command invocation for command `dirName`
  ##
  result = indentation
  result.add(dirName)
  result.add(' ')

func asmDataDirective(d: DataDirectives): string =
  ## Start an RGBASM data command invocation for the given directive.
  ##
  result = asmDirective($d)

func dataSize(dir: DataDirectives): int =
  ## Gets the element size, in bytes, for the given data directive.
  ##
  case dir
  of dDb: sizeof(AsmByte)
  of dDw: sizeof(AsmWord)
  of dDl: sizeof(AsmLong)

func initDataBuilder(dir: DataDirectives): DataBuilder =
  ## Initialize a new DataBuilder for the given data directive.
  ##
  result.output = asmDataDirective(dir)
  # newline is the line joiner '\' followed by a newline and some alignment spaces
  result.newline = "\\\n"
  for i in 0..<result.output.len:
    result.newline.add(' ')
  
  # determine the number of items per line using the formula:
  # 
  # C(n) = e*n + (n - 1)*d
  #
  # Where:
  #   C(n): the number of chars needed for n elements
  #   e: chars per element
  #   d: chars per delimiter
  #
  # to find n for some available amount of space, s:
  # s = e*n + (n - 1)*d
  # s = e*n + d*n - d
  # s + d = (e + d)*n
  # (s + d) / (e + d) = n

  # for s, we will use lineLength subtract the number of chars needed for the
  # directive.
  
  let 
    e = dataSize(dir) * 2 + 1           # chars per element
    d = len(commaDelim)                 # chars per delimiter
    s = lineLength - len(result.output) # available space

  # default to 1 if s is not big enough for a single item
  result.itemsPerLine = max(1, (s + d) div (e + d))

proc add(b: var DataBuilder; item: string) =
  ## Add an item to the builder's output
  ##
  if b.itemsOnLine > 0:
    b.output.add(commaDelim)
    if b.itemsOnLine == b.itemsPerLine:
      b.output.add(b.newline)
      b.itemsOnLine = 0
  
  b.output.add(item)
  inc b.itemsOnLine

func asmHexLiteral*[T: SomeAsmInt](num: T): string =
  ## Converts `num` to a hexadecimal literal in RGBASM syntax.
  ##
  result.add('$')
  result.add(toHex(num, sizeof(T) * 2))

func asmString*(s: string): string =
  ## Converts `s` to a string literal in RGBASM syntax. Escape sequences such as
  ## '\\', '\"', '\n', '\r', and '\t' are properly escaped. Note that '{' and
  ## '}' are used for symbol interpolation, so if you need these characters you
  ## must escape them with a backslash, ie, `"\\{\\}"`
  ##
  result.add('"')
  for ch in s:
    case ch
    of '\\':  result.add r"\\"
    of '\"':  result.add "\\\""
    of '\n':  result.add r"\n"
    of '\r':  result.add r"\r"
    of '\t':  result.add r"\t"
    else:     result.add ch
  result.add('"')

func asmEncode*(data: string): string =
  ## Encodes the given data string using RGBASM syntax.
  ## 
  result = asmDataDirective(dDb)
  result.add(asmString(data))

func asmEncode*[T: SomeAsmInt](data: T): string =
  ## Encodes the given integer using RGBASM syntax. The code generated is a
  ## DB/DW/DL command call followed by `data` as a hexadecimal literal.
  ##
  const dir = getDataDirective(T)
  result = asmDataDirective(dir)
  result.add(asmHexLiteral(data))

func asmEncode*[T: SomeAsmInt](data: openArray[T]): string =
  ## Encodes the given array of integers using RGBASM syntax. The assembly code
  ## generated is a DB/DW/DL command call with a comma-delimited list of
  ## integer literals in hexadecimal format. The code is formatted to fit
  ## within 80 columns per line.
  ##
  const dir = getDataDirective(T)
  var b = initDataBuilder(dir)
  for d in data:
    b.add(asmHexLiteral(d))
  result = b.output

func asmEncode*[T: object](data: T): string =
  ## Encodes an object to RGBASM syntax. The size of `T` must be known. The
  ## object is encoded as a byte array with the same size of `T`.
  ##
  let dataBytes = cast[ptr UncheckedArray[byte]](unsafeAddr(data))
  result = asmEncode(toOpenArray(dataBytes, 0, sizeof(T) - 1))

func asmDs*(amount: Positive): string =
  ## Generates an RGBASM DS command call with the given amount, in bytes.
  ##
  result = asmDirective("DS")
  result.add($amount)

func asmComment*(text: string; indented = true): string =
  ## Generates an assembly line comment, with optional indentation.
  ##
  if indented:
    result = indentation
  result.add("; ")
  result.add(text)
