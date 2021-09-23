
project(examples LANGUAGES CXX)

add_library(wav STATIC "Wav.cpp" "Wav.hpp")

add_executable(demo "demo.cpp")
target_link_libraries(demo PRIVATE trackerboy wav)
