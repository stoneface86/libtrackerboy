
project(examples LANGUAGES CXX)

# library for writing wav files
add_library(wav STATIC "Wav.cpp" "Wav.hpp")

add_executable(example_apu "example_apu.cpp")
target_link_libraries(example_apu PRIVATE trackerboy wav)

add_executable(example_instruments "example_instruments.cpp")
target_link_libraries(example_instruments PRIVATE trackerboy wav)

add_executable(example_song "example_song.cpp")
target_link_libraries(example_song PRIVATE trackerboy wav)


add_executable(runner "runner.cpp")
target_link_libraries(runner PRIVATE trackerboy)
