##[

.. include:: warning.rst

]##


import ../common

import std/options

type
  EngineFrame* = object
    ## Informational data about the current engine frame being stepped.
    ## 
    halted*: bool
      ## Indicates if the song has halted
    startedNewRow*: bool
      ## Indicates if this frame is the first of a new row being stepped.
    startedNewPattern*: bool
      ## Indicates if this frame is the first step of a new pattern.
    speed*: uint8
      ## Current playback speed, in Q4.4 format.
    time*: int
      ## time index of the frame
    order*: int
      ## Current pattern index
    row*: int
      ## Current row index

  PatternCommand* = enum
    pcNone
    pcNext
    pcJump

  UpdateFlag* = enum
    ufTimbre
    ufEnvelope
    ufPanning
    ufFrequency

  UpdateFlags* = set[UpdateFlag]

  ChannelState* = object
    ## State of a channel
    envelope*: uint16
    timbre*: uint8
    panning*: uint8
    frequency*: uint16

  ChannelAction* = enum
    caNone      ## No action, do not update channel
    caUpdate    ## Update the channel by writing its registers
    caCut       ## Note stopped, turn DAC off
    caShutdown  ## Channel was unlocked, zero the channel's registers

  ChannelUpdate* = object
    case action*: ChannelAction
    of caNone:
      discard
    of caUpdate:
      flags*: UpdateFlags
      state*: ChannelState
      trigger*: bool
    of caCut:
      discard
    of caShutdown:
      discard

  GlobalState* = object
    ## State of the music runtime that is accessible by all tracks
    patternCommand*: PatternCommand
    patternCommandParam*: uint8
    panning*: array[ChannelId, uint8]
    speed*: uint8
    sweep*: Option[uint8]
    volume*: Option[uint8]
    halt*: bool

  ApuOperation* = object
    ## An operation or modification to be made to an ApuIo object
    ## Stepping the Engine results in an ApuOperation
    updates*: array[ChannelId, ChannelUpdate]
    sweep*: Option[uint8]
    volume*: Option[uint8]
    #lengthTable: array[ChannelId, Option[uint8]]

const
  ufAll* = {UpdateFlag.low..UpdateFlag.high}

func init*(_: typedesc[ChannelState]): ChannelState =
  ChannelState(envelope: 0xFFFF, timbre: 0xFF, panning: 0xFF, frequency: 0xFFFF)

func init*(T: typedesc[GlobalState]): GlobalState =
  discard