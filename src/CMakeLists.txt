
set(PUB_HEADERS
    "../include/trackerboy/apu/IApu.hpp"
    "../include/trackerboy/apu/NullApu.hpp"
    "../include/trackerboy/data/DataItem.hpp"
    "../include/trackerboy/data/InfoStr.hpp"
    "../include/trackerboy/data/Instrument.hpp"
    "../include/trackerboy/data/Module.hpp"
    "../include/trackerboy/data/Order.hpp"
    "../include/trackerboy/data/OrderRow.hpp"
    "../include/trackerboy/data/Pattern.hpp"
    "../include/trackerboy/data/PatternMap.hpp"
    "../include/trackerboy/data/PatternRow.hpp"
    "../include/trackerboy/data/Sequence.hpp"
    "../include/trackerboy/data/Song.hpp"
    "../include/trackerboy/data/SongList.hpp"
    "../include/trackerboy/data/Table.hpp"
    "../include/trackerboy/data/Track.hpp"
    "../include/trackerboy/data/TrackRow.hpp"
    "../include/trackerboy/data/Waveform.hpp"
    "../include/trackerboy/engine/ChannelControl.hpp"
    "../include/trackerboy/engine/ChannelState.hpp"
    "../include/trackerboy/engine/Engine.hpp"
    "../include/trackerboy/engine/Frame.hpp"
    "../include/trackerboy/engine/FrequencyControl.hpp"
    "../include/trackerboy/engine/GlobalState.hpp"
    "../include/trackerboy/engine/InstrumentRuntime.hpp"
    "../include/trackerboy/engine/MusicRuntime.hpp"
    "../include/trackerboy/engine/Operation.hpp"
    "../include/trackerboy/engine/RuntimeContext.hpp"
    "../include/trackerboy/engine/Timer.hpp"
    "../include/trackerboy/engine/TrackControl.hpp"
    "../include/trackerboy/export/Player.hpp"
    "../include/trackerboy/InstrumentPreview.hpp"
    "../include/trackerboy/note.hpp"
    "../include/trackerboy/Synth.hpp"
    "../include/trackerboy/trackerboy.hpp"
    "../include/trackerboy/Version.hpp"
)

set(SRC_FILES
    "apu/NullApu.cpp"
    "apu/IApu.cpp"

    "data/DataItem.cpp"
    "data/InfoStr.cpp"
    "data/Instrument.cpp"
    "data/Module.cpp"
    "data/Order.cpp"
    "data/Pattern.cpp"
    "data/PatternMap.cpp"
    "data/Sequence.cpp"
    "data/Song.cpp"
    "data/SongList.cpp"
    "data/Table.cpp"
    "data/Track.cpp"
    "data/TrackRow.cpp"
    "data/Waveform.cpp"

    "engine/ChannelControl.cpp"
    "engine/Engine.cpp"
    "engine/FrequencyControl.cpp"
    "engine/InstrumentRuntime.cpp"
    "engine/MusicRuntime.cpp"
    "engine/Operation.cpp"
    "engine/RuntimeContext.cpp"
    "engine/Timer.cpp"
    "engine/TrackControl.cpp"

    "export/Player.cpp"
    
    "internal/fileformat/payload/deserializePayload0.cpp"
    "internal/fileformat/payload/deserializePayload1.cpp"
    "internal/fileformat/payload/payload.cpp"
    "internal/fileformat/payload/payload.hpp"
    "internal/fileformat/payload/PayloadHandler.hpp"
    "internal/fileformat/payload/serializePayload.cpp"
    "internal/fileformat/payload/handlers/CommHandler.cpp"
    "internal/fileformat/payload/handlers/CommHandler.hpp"
    "internal/fileformat/payload/handlers/InstHandler.cpp"
    "internal/fileformat/payload/handlers/InstHandler.hpp"
    "internal/fileformat/payload/handlers/SongHandler.cpp"
    "internal/fileformat/payload/handlers/SongHandler.hpp"
    "internal/fileformat/payload/handlers/TableHandler.hpp"
    "internal/fileformat/payload/handlers/WaveHandler.cpp"
    "internal/fileformat/payload/handlers/WaveHandler.hpp"
    "internal/fileformat/Block.hpp"
    "internal/fileformat/Block.cpp"
    "internal/fileformat/fileformat.hpp"
    "internal/fileformat/fileformat.cpp"
    "internal/endian.hpp"
    "internal/enumutils.hpp"
    
    "InstrumentPreview.cpp"
    "note.cpp"
    "Synth.cpp"
    "Version.cpp"
)

include(TestBigEndian)
TEST_BIG_ENDIAN(IS_BIG_ENDIAN)

if (IS_BIG_ENDIAN)
    list(APPEND SRC_FILES "internal/endian.cpp")
endif ()


add_library(trackerboy "${SRC_FILES}" "${PUB_HEADERS}")
set_target_properties(trackerboy PROPERTIES PUBLIC_HEADER "${PUB_HEADERS}")
target_compile_features(trackerboy PUBLIC cxx_std_17)

target_include_directories(trackerboy PUBLIC "../include")
target_include_directories(trackerboy PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

if (LIBTRACKERBOY_ENABLE_UNITY)
    if (CMAKE_VERSION VERSION_GREATER 3.15)
        set_target_properties(trackerboy PROPERTIES UNITY_BUILD ON)
    endif ()
endif ()

if (IS_BIG_ENDIAN)
    target_compile_definitions(trackerboy PRIVATE -DTRACKERBOY_BIG_ENDIAN)
endif ()

install(TARGETS trackerboy)

