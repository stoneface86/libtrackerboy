##[

Engine state.

This module contains types that represent the current state of an Engine.

This module is part of the inner workings of the engine module.

]##


import
  std/[options],
  ../common,
  ../data,
  ../tracking

export
  options,
  common,
  data,
  tracking

type
  EngineFrame* = object
    ## Informational data about the current engine frame being stepped.
    ## - `status` - current status of the music tracker.
    ## - `speed` - current playback speed of the song.
    ## - `time` - time index of the frame, first frame is `0`.
    ## - `pos` - current position in the song.
    ## 
    status*: TrackerStatus
    speed*: Speed
    time*: int
    pos*: SongPos

  UpdateFlag* = enum
    ## Flags to indicate which part of the state has changed, and needs to be
    ## updated in the channel's registers.
    ##
    ufTimbre    ## Update timbre setting
    ufEnvelope  ## Update envelope setting
    ufPanning   ## Update panning setting
    ufFrequency ## Update frequency setting

  UpdateFlags* = set[UpdateFlag]
    ## A set of update flags to indicate only the parts of the state that has
    ## changed.
    ##

  ChannelState* = object
    ## State of a channel.
    ## - `envelope` - The envelope setting, `0..255`. Use `0xFFFF` to specify
    ##                initial state.
    ## - `timbre` - The timbre setting, `0..3`. Use `0xFF` to specify initial
    ##              state.
    ## - `panning` - The panning setting, `0..3`. Use `0xFF` to specify
    ##               initial state.
    ## - `frequency` - The frequency setting, `0..2047`. Use `0xFFFF` to
    ##                 specify initial state.
    ##
    envelope*: uint16
    timbre*: uint8
    panning*: uint8
    frequency*: uint16

  ChannelAction* = enum
    ## Specifies which action the channel should do when updating for a single
    ## tick.
    ##
    caNone      ## No action, do not update channel
    caUpdate    ## Update the channel by writing its registers
    caCut       ## Note stopped, turn DAC off
    caShutdown  ## Channel was unlocked, zero the channel's registers

  ChannelUpdate* = object
    ## Object that determines how a channel should be updated for a single
    ## tick.
    ##
    case action*: ChannelAction
      ## The action to take.
      ##
    of caNone:
      discard
    of caUpdate:
      flags*: UpdateFlags
        ## Determines which parts of `state` to update.
        ##
      state*: ChannelState
        ## The current state of the channel
        ##
      trigger*: bool
        ## If `true`, the channel should be retriggered.
        ##
    of caCut:
      discard
    of caShutdown:
      discard

  ApuOperation* = object
    ## An operation or modification to be made to an `ApuIo` object.
    ## Stepping the `Engine` results in an `ApuOperation`
    ## - `updates` - A [ChannelUpdate] for each channel.
    ## - `sweep` - Write to the sweep register with this value when set.
    ## - `volume` - Write to the global volume register with this value when
    ##              set.
    ##
    updates*: array[ChannelId, ChannelUpdate]
    sweep*: Option[uint8]
    volume*: Option[uint8]
    #lengthTable: array[ChannelId, Option[uint8]]

const
  updateAll* = {UpdateFlag.low..UpdateFlag.high}
    ## Update all settings
    ##

func initChannelState*(): ChannelState =
  ## Initialize a [ChannelState] with initial settings. Using this state as an
  ## initial value will guarentee that all settings will be updated on the
  ## first tick.
  ##
  ChannelState(envelope: 0xFFFF, timbre: 0xFF, panning: 0xFF, frequency: 0xFFFF)

