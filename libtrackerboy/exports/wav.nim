##[

WAV file export.

This module provides an exporter for exporting individual songs in a module to
a WAV file. The song is played, the APU is emulated, and the resulting
sound samples are written to an output WAV file.

There are two ways of using this module: `one-shot <#oneminusshot>`_ and
`iterative <#iterative>`_.

One-shot
--------

One-shot mode is done by just calling the
`exportWav <#exportWav,Module,WavConfig>`_ proc. The WAV file is generated in
that proc alone according to the given configuration.

Iterative
---------

Iterative mode is done by creating a `WavExporter <#WavExporter>`_ object and
then calling the `process <#process,WavExporter,Module>`_ proc repeatedly until 
`hasWork <#hasWork,WavExporter>`_ is false. You can use the
`progress <#progress,WavExporter>`_ and `progressMax <#progressMax,WavExporter>`_
procs to display overall progress of the export.

This mode is preferred for GUI applications, so that you can report progress
to the user while the export is in process.

Example:

.. code:: nim
  var config = WavConfig.init()
  config.filename = "out.wav"
  var ex = WavExporter.init(module, config)
  # progressBar.setMax(ex.progressMax)
  while ex.hasWork():
    # progressBar.setValue(ex.progress)
    ex.process(module)

]##


import 
  ../apu,
  ../data,
  ../engine,
  ../private/wavwriter

import std/os

type

  SongDuration* = object
    ## Duration of the song to export. The amount can either be specified in
    ## number of loops, or a `Duration` from `std/times`.
    ##
    case unitInLoops*: bool
      ## If `true`, then this duration will loop the song a given number of
      ## times. If `false, then this duration will use a time duration.
      ##
    of true:
      loopAmount*: Positive
        ## Number of times to loop the song
        ##
    of false:
      timeAmount*: Duration
        ## Amount of time to play the song for.
        ##

  WavConfig* = object
    ## Configuration of the WAV file to create.
    ## 
    song*: Natural
      ## Index of the song in the module to export. Default is 0, or the first
      ## song.
      ##
    duration*: SongDuration
      ## The duration to export. Default is a time unit of 1 minute.
      ##
    filename*: string
      ## Destination filename of the output WAV file.
      ##
    samplerate*: Natural
      ## Output samplerate, in Hertz, of the output WAV file. Must not be 0.
      ## Default is 44100 Hz.
      ##
    channels*: set[ChannelId]
      ## Set of channels to export. Default is all channels.
      ##
    isMono*: bool
      ## If set to true, the output file will be in mono sound (1 sound channel).
      ## stereo otherwise. Mono sound conversion is done by averaging the left
      ## and right channels. Default is false, or stereo sound.
      ##

  WavExporter* = object
    ## WavExporter object for iterative mode. An exporter can be created via
    ## the `init <#init,typedesc[WavExporter],Module,WavConfig>`_ proc.
    ## 
    apu: Apu
    engine: Engine
    writer: WavWriter
    framesRendered: int
    framesToRender: int
    buf: seq[Pcm]
    isMono: bool

func songDuration*(loops: Positive): SongDuration =
  ## Initializes a song duration with the given number of loops.
  ##
  SongDuration(unitInLoops: true, loopAmount: loops)

func songDuration*(time: Duration): SongDuration =
  ## Initializes a song duration with the given time amount
  ##
  SongDuration(unitInLoops: false, timeAmount: time)

func init*(T: typedesc[WavConfig]): WavConfig =
  ## Initializes a WavConfig with default settings.
  ## 
  WavConfig(
    samplerate: 44100,
    channels: {ch1..ch4},
    duration: songDuration(initDuration(minutes = 1))
  )

proc init*(T: typedesc[WavExporter]; module: Module; config: WavConfig
          ): WavExporter {. raises: [IOError] .} =
  ## Initializes a WavExporter for a given module and config. The output WAV
  ## file specified in `config` is created and ready to be filled with samples.
  ## 
  ## The export can continue by calling `process <#process,WavExporter,Module>`_ repeatedly until
  ## `hasWork <#hasWork,WavExporter>`_ returns `false`.
  ## 
  ## An `IOError` will be raised if the output file could not be written to.
  ##
  
  let 
    tickrateHz = module.getTickrate(config.song).hertz()
    wavChannels = if config.isMono: 1 else: 2
    song = module.songs[config.song]
    runtime = block:
      if config.duration.unitInLoops:
        runtime(song[], config.duration.loopAmount)
      else:
        runtime(config.duration.timeAmount, tickrateHz)

  result = WavExporter(
    apu: Apu.init(config.samplerate, tickrateHz),
    engine: Engine.init(),
    writer: WavWriter.init(config.filename, wavChannels, config.samplerate),
    framesRendered: 0,
    framesToRender: runtime,
    buf: newSeq[Pcm](),
    isMono: config.isMono
  )
  result.engine.play(song)
  result.apu.setup()
  for ch in ChannelId:
    if ch in config.channels:
      result.engine.lock(ch)
    else:
      result.engine.unlock(ch)


func hasWork*(ex: WavExporter): bool {. raises: [] .} =
  ## Returns `true` if the exporter still has work to do, `false` otherwise.
  ## 
  ex.framesRendered < ex.framesToRender

proc process*(ex: var WavExporter; module: Module) {. raises: [IOError] .} =
  ## Processes a single frame and writes it to the destination WAV file. If the
  ## exporter is finished this proc does nothing. Use
  ## `hasWork <#hasWork,WavExporter>`_ to check before calling this proc.
  ## 
  ## An `IOError` may be raised if any error occurred during writing to the
  ## output WAV file.
  ## 
  if ex.hasWork():
    ex.engine.stepAndApply(module.instruments, module.waveforms, ex.apu)
    ex.apu.runToFrame()
    ex.apu.takeSamples(ex.buf)
    if ex.isMono:
      # convert the stereo buffer to a mono one by averaging the L and R samples
      let samples = ex.buf.len div 2
      var frameIndex = 0
      for i in 0..<samples:
        let sample = (ex.buf[frameIndex] + ex.buf[frameIndex + 1]) / 2.0f
        ex.buf[i] = sample
        frameIndex += 2
      ex.buf.setLen(samples)
    ex.writer.write(ex.buf)
    inc ex.framesRendered

func progress*(ex: WavExporter): int {. raises: [] .} =
  ## Gets a number representing the total overall progress made towards the
  ## export. The number returned will be in the range `0..ex.progressMax`.
  ## 
  ex.framesRendered

func progressMax*(ex: WavExporter): int {. raises: [] .} =
  ## Gets a number representing the maximum of the values returned by
  ## `progress <#progress,WavExporter>`_.
  ## 
  ex.framesToRender

proc batched*(config: WavConfig): seq[WavConfig] {. raises: [] .} =
  ## Creates a sequence of WavConfigs where each channel in `config` gets its
  ## own output file. The filename in each of these configs gets a suffix added
  ## to the filename, ie `$name.ch$channel.$ext`.
  ## 
  ## Use this when exporting each channel separately is desired.
  ## 
  let (dir, name, ext) = splitFile(config.filename)
  for ch in config.channels:
    var batch = config
    batch.channels = {ch}
    batch.filename = block:
      var res = name
      res.add(".ch")
      res.add($(ch.ord + 1))
      res.add('.')
      res.add(ext)
      dir / res
    result.add(batch)

proc exportWav*(module: Module; config: WavConfig) {. raises: [IOError] .} =
  ## Exports a song in module to WAV using the given config.
  ## 
  ## An `IOError` may be raised if the output WAV file could not be written to.
  ## 
  var ex = WavExporter.init(module, config)
  while ex.hasWork():
    ex.process(module)
