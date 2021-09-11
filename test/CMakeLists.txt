
find_package(Catch2 CONFIG REQUIRED)

include(Catch)
enable_testing()

add_executable(test_trackerboy
    "data/test_Table.cpp"
    "data/test_Module.cpp"
    "data/test_PatternMap.cpp"
    
    "engine/test_InstrumentRuntime.cpp"
    "engine/test_Timer.cpp"

    "internal/test_endian.cpp"
    "internal/fileformat/test_Block.cpp"

    "catch.cpp"
)

target_link_libraries(test_trackerboy PRIVATE trackerboy Catch2::Catch2)
target_include_directories(test_trackerboy PRIVATE "${CMAKE_SOURCE_DIR}/src")
if (IS_BIG_ENDIAN)
    target_compile_definitions(test_trackerboy PRIVATE -DTRACKERBOY_BIG_ENDIAN)
endif ()

catch_discover_tests(test_trackerboy)
