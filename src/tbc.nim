# tbc - trackerboy compiler
# command line frontend for libtrackerboy

import std/[options, parseopt, streams, strformat, strutils]
export options

import trackerboy/data
import trackerboy/exports/wav

# types/fields are exported solely for unit testing

type
    SubCommand* = enum
        scWav

    SubCommandConfig* = object
        case kind*: SubCommand
        of scWav:
            wavSeparate*: bool
            wavConfig*: WavConfig

    ShortCircuit* = enum
        shortNone
        shortHelp
        shortVersion

    ExitCodes* = enum
        exitFailure = -1
        exitSuccess = 0
        exitBadArguments
        exitFileError
        exitModuleError

    Tbc* = object
        subcmd*: Option[SubCommand]
        shortCircuit*: ShortCircuit
        modulePath*: string
        subcmdConfig*: SubCommandConfig
        # error messages get written here instead of stderr, for unit testing
        when not isMainModule:
            output*: string

const

    subcommandNames: array[SubCommand, string] = [
        "wav"
    ]

template writeErr(app: var Tbc, str: string): untyped =
    when isMainModule:
        stderr.write str
    else:
        app.output.add str

func maybeParseInt(str: string, bounds: Slice[int]): Option[int] =
    var num: int
    try:
        num = str.parseInt()
    except ValueError:
        return none(int)
    if num in bounds:
        result = some(num)

template maybeParseInt(str: string, rangeT: typedesc[range]): Option[int] =
    maybeParseInt(str, rangeT.low.int..rangeT.high.int)

func init(T: typedesc[SubCommandConfig], sub: SubCommand): T.typeOf =
    case sub:
    of scWav:
        T(
            kind: scWav,
            wavConfig: WavConfig.init()
        )

proc parseSubcmdArg(app: var Tbc, key, val: string): bool =
    func unrecognizedOption(opt: string): string =
        &"Error: unrecognized option '{opt}'\n"
    template config(): untyped = app.subcmdConfig
    case config.kind:
    of scWav:
        case key:
        of "i", "song":
            let index = maybeParseInt(val, ByteIndex)
            if index.isSome():
                config.wavConfig.song = index.get()
            else:
                app.writeErr "Error: invalid song index\n"
                return true
        of "o", "output":
            config.wavConfig.filename = val
        of "r", "samplerate":
            let samplerate = maybeParseInt(val, 1..int.high)
            if samplerate.isSome():
                config.wavConfig.samplerate = samplerate.get()
            else:
                app.writeErr "Error: invalid samplerate\n"
                return true
        of "c", "channels":
            let channels = val.split(',')
            if channels.len > 4:
                app.writeErr "Error: too many channels\n"
                return true
            var channelset: set[ChannelId]
            for ch in channels:
                let num = maybeParseInt(ch, 1..4)
                if num.isNone():
                    app.writeErr "Error: invalid channel number\n"
                    return true
                channelset.incl(ChannelId(num.get()-1))
            config.wavConfig.channels = channelset
        of "separate":
            config.wavSeparate = true
        else:
            app.writeErr unrecognizedOption(key)
            return true

proc init*(tbc: var Tbc, cmd = ""): ExitCodes =
    var p = initOptParser(
        cmd,
        shortNoVal = {'h', 'v'},
        longNoVal = @["help", "version", "separate"]
    )
    var argCount = 0
    for kind, key, val in p.getopt():
        case p.kind:
        of cmdEnd:
            break
        of cmdArgument:
            case argCount:
            of 0:
                for sub, name in subcommandNames.pairs:
                    if name.cmpIgnoreCase(key) == 0:
                        tbc.subcmd = some(sub)
                        tbc.subcmdConfig = SubCommandConfig.init(sub)
                        break
                if tbc.subcmd.isNone():
                    tbc.writeErr &"Error: invalid command '{key}'\n"
                    return exitBadArguments
            of 1:
                tbc.modulePath = key
            else:
                tbc.writeErr "Error: too many arguments given\n"
                return exitBadArguments
            inc argCount
        of cmdShortOption, cmdLongOption:
            case key:
            of "help", "h":
                tbc.shortCircuit = shortHelp
                break
            of "version", "v":
                tbc.shortCircuit = shortVersion
                break
            else:
                if tbc.subcmd.isSome():
                    if parseSubcmdArg(tbc, key, val):
                        return exitBadArguments
                else:
                    tbc.writeErr &"Error: command required before option: '{key}'\n"
                    return exitBadArguments

    if tbc.shortCircuit == shortNone and argCount != 2:
        tbc.writeErr "Error: not enough arguments given\n"
        tbc.writeErr "Usage: tbc <command> <module> [options]\n"
        return exitBadArguments

    result = exitSuccess



when isMainModule:
    import trackerboy/[io, version]
    import std/exitprocs

    const subcommandDesc: array[SubCommand, string] = [
            "Exports a song to a WAV file"
        ]

    func generateHelpPage(sub: SubCommand): string {.compileTime.} =
        result = "\nUsage:\n    tbc " & subcommandNames[sub] &
                " <module> [options]\n\nCommand options:\n"
        case sub:
        of scWav:
            result.add("""
        -o, --output        Specify the output file name
        -i, --song          Select the song index to export (default is 0)
        -s, --samplerate    Specify the output samplerate (default is 44100)
        -c, --channels      Only export the specified channels, as a comma speparated list of numbers (default is 1,2,3,4)
        --separate          Export each channel as a separate file
            """)

    func generateHelpPages(): array[SubCommand, string] {.compileTime.} =
        for sub, page in result.mpairs:
            page = generateHelpPage(sub)

    const
        helpPages = generateHelpPages()
        helpMain = block:
            var result = """

Command line frontend for libtrackerboy. Converts a trackerboy module to
various formats.

Usage:
    tbc <command> <module> [options]

Command:
"""
            for sub in SubCommand:
                result.add("    ")
                result.add(subcommandNames[sub])
                result.add("    ")
                result.add(subcommandDesc[sub])
                result.add("\n")
            result.add("\nGeneral options:\n")
            result.add("""
    -h, --help      Show help information and exit
    -v, --version   Show version information and exit
""")
            result.add("\nPass -h with the command for more help")
            result

    proc showVersion() =
        echo &"Trackerboy compiler v{libVersion} [Trackerboy v{appVersion}]"

    proc showHelp(sub: Option[SubCommand]) =
        showVersion()
        if sub.isSome():
            echo helpPages[sub.get()]
        else:
            echo helpMain

    func toExitCode(b: bool): ExitCodes =
        if b: exitSuccess else: exitFailure

    proc wav(tbc: var Tbc, module: var Module): ExitCodes =
        proc updateFilename(config: var WavConfig, module: Module) =
            if config.filename.len == 0:
                discard
        tbc.subcmdConfig.wavConfig.updateFilename(module)
        if tbc.subcmdConfig.wavSeparate:
            for batch in batched(tbc.subcmdConfig.wavConfig):
                if not module.exportWav(batch):
                    return exitFailure
            result = exitSuccess
        else:
            result = module.exportWav(tbc.subcmdConfig.wavConfig).toExitCode

    proc open(tbc: var Tbc, module: var Module): ExitCodes =
        # open the module
        var module = Module.init()
        try:
            let strm = openFileStream(tbc.modulePath)
            let error = module.deserialize(strm)
            if error != frNone:
                stderr.write &"Error: could not read module: {error}\n"
                return exitModuleError
        except:
            let errmsg = getCurrentExceptionMsg()
            stderr.write &"Error: could not open '{tbc.modulePath}': {errmsg}\n"
            return exitFileError

    proc main(): ExitCodes =
        template errCheck(exitcode: ExitCodes): untyped =
            block:
                let code = exitcode
                if code != exitSuccess:
                    return code

        # process arguments
        var tbc: Tbc
        errCheck(tbc.init())

        case tbc.shortCircuit:
        of shortNone:
            discard
        of shortHelp:
            showHelp(tbc.subcmd)
            return exitSuccess
        of shortVersion:
            showVersion()
            return exitSuccess

        # load module
        var module = Module.init()
        errCheck(tbc.open(module))

        # dispatch
        case tbc.subcmd.get():
        of scWav:
            wav(tbc, module)
    
    setProgramResult main().ord
