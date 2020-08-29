# Use a recent version of CMake
cmake_minimum_required(VERSION 3.12)


# Define the project details
project("SoftEther VPN"
    VERSION 5.01.9674
    LANGUAGES C)


# Set global variables
set(TOP_DIRECTORY ${CMAKE_SOURCE_DIR})
set(BUILD_DIRECTORY ${CMAKE_BINARY_DIR})


# Include helper files
include(${CMAKE_CURRENT_LIST_DIR}/cmake/utils.cmake)


# Events before the build
assert_requirements()
unix_set_unitfiles()
unix_set_packaging()
set_timestamp()


# Configure files
configure_file("${TOP_DIRECTORY}/AUTHORS.TXT" "${TOP_DIRECTORY}/src/bin/hamcore/authors.txt" COPYONLY)


# Add definitions for all targets in this project
add_global_definitions()


# Add include directories for all targets in this project
include_directories(src)


# Add targets
add_subdirectory(src/Cedar)
add_subdirectory(src/Mayaqua)
add_subdirectory(src/hamcorebuilder)
add_subdirectory(src/vpnserver)
add_subdirectory(src/vpnclient)
add_subdirectory(src/vpnbridge)
add_subdirectory(src/vpncmd)
add_subdirectory(src/vpntest)


# hamcore.se2 archive file
add_custom_target(hamcore-archive-build
    ALL
    COMMAND hamcorebuilder "${TOP_DIRECTORY}/src/bin/hamcore/" "${BUILD_DIRECTORY}/hamcore.se2"
    DEPENDS hamcorebuilder
    COMMENT "Building hamcore.se2 archive file..."
    VERBATIM)


# Add Windows-specific targets
if(WIN32)
    add_subdirectory(src/PenCore)
    add_dependencies(hamcore-archive-build PenCore)

    add_subdirectory(src/vpndrvinst)
    add_dependencies(hamcore-archive-build vpndrvinst)

    add_subdirectory(src/vpnsmgr)
    add_subdirectory(src/vpncmgr)
    add_subdirectory(src/vpnsetup)
endif()


# Events after the build
unix_print_install()
