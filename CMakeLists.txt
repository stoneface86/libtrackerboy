
cmake_minimum_required(VERSION 3.9...3.21)

project(
    libtrackerboy
    VERSION 0.1.0   
    LANGUAGES CXX
)

option(LIBTRACKERBOY_ENABLE_TESTS "Enable unit tests (requires Catch2)" OFF)
option(LIBTRACKERBOY_ENABLE_EXAMPLES "Enable example programs" OFF)
option(LIBTRACKERBOY_ENABLE_UNITY "Enables unity build" OFF)
# default is static library
option(BUILD_SHARED_LIBS "Builds a shared library if enabled" OFF)

if (CMAKE_PROJECT_NAME STREQUAL PROJECT_NAME)
    set(__IS_ROOT TRUE)
    set(__PARENT_SOURCE_DIR "${CMAKE_SOURCE_DIR}")
else ()
    # we are being included from another project via add_subdirectory
    set(__IS_ROOT FALSE)
    set(__PARENT_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
endif ()

if (__IS_ROOT)
    
    include(CTest)

    set_property(GLOBAL PROPERTY USE_FOLDERS ON)

    # find_package(Doxygen)
    # if (Doxygen_FOUND)
    #   add_subdirectory(docs)
    # else ()
    #   message(STATUS "Doxygen not found, documentation will NOT be generated")
    # endif ()


endif ()

# builds the library
add_subdirectory(src)

if (LIBTRACKERBOY_ENABLE_EXAMPLES)
    add_subdirectory(examples)
endif ()

if ((__IS_ROOT AND BUILD_TESTING) OR LIBTRACKERBOY_ENABLE_TESTS)
    add_subdirectory(test)
endif ()


unset(__IS_ROOT)
unset(__PARENT_SOURCE_DIR)
