
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
    set(__IS_SUBDIRECTORY FALSE)
else ()
    set(__IS_SUBDIRECTORY TRUE)
endif ()

if (NOT __IS_SUBDIRECTORY)
    
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

if (NOT __IS_SUBDIRECTORY OR LIBTRACKERBOY_ENABLE_EXAMPLES)
    #add_subdirectory(examples)
endif ()

if (NOT __IS_SUBDIRECTORY OR LIBTRACKERBOY_ENABLE_TESTS)
    # unit tests if we are not in a subdirectory
    add_subdirectory(test)
endif ()


unset(__IS_SUBDIRECTORY)
