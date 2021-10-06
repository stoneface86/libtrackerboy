## Welcome

libtrackerboy is a support library for the [Trackerboy](https://github.com/stoneface86/trackerboy). 
The library handles:
 * Reading/Writing trackerboy module files
 * Manipulating/reading module data
 * Gameboy APU emulation
 * Module playback
 * (Coming soon) export to [tbengine](https://github.com/stoneface86/tbengine) format.

## Documentation

Coming soon.

## Build

You will need:
 - git
 - cmake (3.9 or newer)
 - C++ compiler with the C++17 standard
 - (optional) Catch2 for testing

```sh
git clone https://github.com/stoneface86/libtrackerboy
cd libtrackerboy
cmake -S . -B build -DBUILD_TESTING=OFF
cmake --build build  --target all
# (optional) install
cmake --build build --target install
```

## Use (installed in system)

In your CMakeLists.txt
```cmake
find_package(trackerboy CONFIG REQUIRED)
# ...
target_link_libraries(app PRIVATE trackerboy::trackerboy)
```

## Use (as a subdirectory)

In your CMakeLists.txt
```cmake
add_subdirectory(path_to_libtrackerboy)
# ...
target_link_libraries(app PRIVATE trackerboy)
```
