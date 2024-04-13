##[

Engine state.

This module contains types that represent the current state of an Engine.

This module is part of the inner workings of the engine module.

]##


import
  ../common,
  ../ir,
  ../private/utils

import std/options

type
  EngineFrame* = object
    ## Informational data about the current engine frame being stepped.
    ## 
    halted*: bool
      ## Indicates if the song has halted
      ##
    startedNewRow*: bool
      ## Indicates if this frame is the first of a new row being stepped.
      ##
    startedNewPattern*: bool
      ## Indicates if this frame is the first step of a new pattern.
      ##
    speed*: uint8
      ## Current playback speed, in Q4.4 format.
      ##
    time*: int
      ## time index of the frame
      ##
    order*: int
      ## Current pattern index
      ##
    row*: int
      ## Current row index
      ##

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
    ## State of a channel
    ##
    envelope*: uint16
      ## The envelope setting, `0..255`. Use `0xFFFF` to specify initial state.
      ##
    timbre*: uint8
      ## The timbre setting, `0..3`. Use `0xFF` to specify initial state.
      ##
    panning*: uint8
      ## The panning setting, `0..3`. Use `0xFF` to specify initial state.
      ##
    frequency*: uint16
      ## The frequency setting, `0..2047`. Use `0xFFFF` to specify initial
      ## state.
      ##

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

  GlobalState* = object
    ## State of the music runtime that is accessible by all tracks.
    ##
    patternCommand*: PatternCommand
      ## The pattern command to execute on the next tick
      ##
    patternCommandParam*: uint8
      ## Argument to `patternCommand`
      ##
    panning*: array[ChannelId, uint8]
      ## Channel panning settings
      ##
    speed*: uint8
      ## Set this to change the speed on the next tick. Set to `0u8` to keep
      ## the speed as is.
      ##
    sweep*: Option[uint8]
      ## When set, the sweep register will be written to next tick with
      ## this value.
      ##
    volume*: Option[uint8]
      ## When set, the global volume register will be written to next tick with
      ## this value.
      ##
    halt*: bool
      ## Set this to `true` to stop music playback.
      ## 

  ApuOperation* = object
    ## An operation or modification to be made to an `ApuIo` object.
    ## Stepping the `Engine` results in an `ApuOperation`
    ##
    updates*: array[ChannelId, ChannelUpdate]
      ## A `ChannelUpdate` for each channel.
      ##
    sweep*: Option[uint8]
      ## Write to the sweep register with this value when set.
      ##
    volume*: Option[uint8]
      ## Write to the global volume register with this value when set.
      ##
    #lengthTable: array[ChannelId, Option[uint8]]

const
  ufAll* = {UpdateFlag.low..UpdateFlag.high}
    ## Update all settings
    ##

func initChannelState*(): ChannelState =
  ## Initialize a `ChannelState` with initial settings. Using this state as an
  ## initial value will guarentee that all settings will be updated on the
  ## first tick.
  ##
  ChannelState(envelope: 0xFFFF, timbre: 0xFF, panning: 0xFF, frequency: 0xFFFF)

func initGlobalState*(): GlobalState =
  ## Initializes a `GlobalState` with initial settings.
  ##
  defaultInit(result)
