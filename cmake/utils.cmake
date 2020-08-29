# This file is included in multiple places, so it uses a header guard
get_property(__UTILS_INCLUDED GLOBAL PROPERTY CMAKEGUARD.__UTILS_INCLUDED SET)
if (__UTILS_INCLUDED)
    return()
endif()
set_property(GLOBAL PROPERTY CMAKEGUARD.__UTILS_INCLUDED 1)


# Assert that requirements for building the project are met
macro(assert_requirements)
    # Compare ${PROJECT_VERSION} and src/CurrentBuild.txt
    file(READ ${CMAKE_CURRENT_LIST_DIR}/src/CurrentBuild.txt CurrentBuild)

    string(REGEX MATCH      "VERSION_MAJOR ([0-9]+)" temp ${CurrentBuild})
    string(REGEX REPLACE    "VERSION_MAJOR ([0-9]+)" "\\1" CurrentBuild_MAJOR ${temp})
    string(REGEX MATCH      "VERSION_MINOR ([0-9]+)" temp ${CurrentBuild})
    string(REGEX REPLACE    "VERSION_MINOR ([0-9]+)" "\\1" CurrentBuild_MINOR ${temp})
    string(REGEX MATCH      "VERSION_BUILD ([0-9]+)" temp ${CurrentBuild})
    string(REGEX REPLACE    "VERSION_BUILD ([0-9]+)" "\\1" CurrentBuild_BUILD ${temp})

    if(NOT ${PROJECT_VERSION} VERSION_EQUAL "${CurrentBuild_MAJOR}.${CurrentBuild_MINOR}.${CurrentBuild_BUILD}")
        message (FATAL_ERROR "PROJECT_VERSION does not match to src/CurrentBuild.txt")
    endif()
    
    # Check that submodules are present only if source was downloaded with git
    if(EXISTS "${TOP_DIRECTORY}/.git" AND NOT EXISTS "${TOP_DIRECTORY}/src/Mayaqua/3rdparty/cpu_features/CMakeLists.txt")
        message(FATAL_ERROR "Submodules are not initialized. Run\n\tgit submodule update --init --recursive")
    endif()
endmacro()


# Print the current date and time
macro(set_timestamp)
    string(TIMESTAMP DATE_DAY "%d" UTC)
    string(TIMESTAMP DATE_MONTH "%m" UTC)
    string(TIMESTAMP DATE_YEAR "%Y" UTC)
    string(TIMESTAMP TIME_HOUR "%H" UTC)
    string(TIMESTAMP TIME_MINUTE "%M" UTC)
    string(TIMESTAMP TIME_SECOND "%S" UTC)

    message(STATUS "Build date: ${DATE_DAY}/${DATE_MONTH}/${DATE_YEAR}")
    message(STATUS "Build time: ${TIME_HOUR}:${TIME_MINUTE}:${TIME_SECOND}")
endmacro()


# On Unix systems, set the location where to install systemd unit files
macro(unix_set_unitfiles)
    if(UNIX)
        include(GNUInstallDirs)
        include(CheckIncludeFile)

        Check_Include_File(sys/auxv.h HAVE_SYS_AUXV)
        if(EXISTS "/lib/systemd/system")
            set(CMAKE_INSTALL_SYSTEMD_UNITDIR "/lib/systemd/system" CACHE STRING "Where to install systemd unit files")
        endif()
    endif()
endmacro()


# On Unix systems, set various packaging configurations
macro(unix_set_packaging)
    if(UNIX)
        # Packaging
        set(CPACK_COMPONENTS_ALL common vpnserver vpnclient vpnbridge vpncmd)
        set(CPACK_PACKAGE_DIRECTORY ${BUILD_DIRECTORY})
        set(CPACK_PACKAGE_VERSION ${PROJECT_VERSION})
        set(CPACK_PACKAGE_VENDOR "SoftEther")
        set(CPACK_PACKAGE_NAME "softether")
        set(CPACK_PACKAGE_DESCRIPTION_FILE "${TOP_DIRECTORY}/description")
        set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "SoftEther VPN is an open-source cross-platform multi-protocol VPN program, created as an academic project in the University of Tsukuba.")

        # DEB
        if(CMAKE_BUILD_TYPE STREQUAL "Debug")
            set(CPACK_DEBIAN_PACKAGE_DEBUG ON)
        endif()

        set(CPACK_DEB_COMPONENT_INSTALL ON)
        set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)
        set(CPACK_DEBIAN_FILE_NAME "DEB-DEFAULT")
        set(CPACK_DEBIAN_PACKAGE_SECTION "net")
        set(CPACK_DEBIAN_PACKAGE_MAINTAINER "Unknown")

        # RPM
        set(CPACK_RPM_COMPONENT_INSTALL ON)
        set(CPACK_RPM_FILE_NAME "RPM-DEFAULT")
        set(CPACK_RPM_PACKAGE_GROUP "Applications/Internet")
        set(CPACK_RPM_PACKAGE_LICENSE "ASL 2.0")

        # Exclude system directories
        if(CPACK_GENERATOR STREQUAL "RPM")
        execute_process(
            COMMAND rpm -ql filesystem
            COMMAND tr \n \;
            OUTPUT_VARIABLE CPACK_RPM_EXCLUDE_FROM_AUTO_FILELIST_ADDITION
            ERROR_QUIET)
        endif()

        include(CPack)
    endif()
endmacro()


# On Unix systems, creates wrapper scripts and installs them in the user's
# binaries directory, which is usually "/usr/local/bin". This is required
# because symlinks use the folder they are in as working directory.
#
# The actual wrapper script needs to be generated at install time, not build
# time, because it depends on the installation prefix. This is especially
# important when generating packages (rpm/deb) where the prefix is changed
# from /usr to /usr/local for the install step.
#
# The placeholder is needed to satisfy the "install" dependency scanner which runs early.
macro(unix_install_wrapper_script component)
    if(UNIX)
        file(GENERATE OUTPUT ${BUILD_DIRECTORY}/${component}.sh
            CONTENT "# placeholder\n")

        install(CODE "file(WRITE ${BUILD_DIRECTORY}/${component}.sh \"#!/bin/sh\nexec \${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBEXECDIR}/softether/${component}/${component} \\\"$@\\\"\n\")"
            COMPONENT ${component})

        install(PROGRAMS ${BUILD_DIRECTORY}/${component}.sh
            COMPONENT ${component}
            DESTINATION bin
            RENAME ${component})
    endif()
endmacro()


# On Unix systems, use the same approach as `unix_install_wrapper_script`
# for systemd unit files
macro(unix_install_unit_file component)
    if(UNIX)
        file(GENERATE OUTPUT ${BUILD_DIRECTORY}/softether-${component}.service
            CONTENT "# placeholder\n")

        install(CODE "set(DIR \"\${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBEXECDIR}\")\nconfigure_file(${TOP_DIRECTORY}/systemd/softether-${component}.service ${BUILD_DIRECTORY}/softether-${component}.service)"
            COMPONENT ${component})

        install(FILES ${BUILD_DIRECTORY}/softether-${component}.service
            COMPONENT ${component}
            DESTINATION ${CMAKE_INSTALL_SYSTEMD_UNITDIR}
            PERMISSIONS OWNER_READ OWNER_WRITE GROUP_READ WORLD_READ)
    endif()
endmacro()


# Adds an application and sets its associated target properties
function(se_add_application app_name)
    add_executable(${app_name} ${ARGN})
    set_property(TARGET ${app_name} PROPERTY POSITION_INDEPENDENT_CODE ON)
    set_target_properties(${app_name}
        PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin/$<CONFIG>")
endfunction()


# Adds a library and sets its associated target properties
function(se_add_library lib_name lib_type)
    add_library(${lib_name} ${lib_type} ${ARGN})
    set_property(TARGET ${lib_name} PROPERTY POSITION_INDEPENDENT_CODE ON)
    
    # Prevent adding the "lib" prefix to be consistent between MSVC & GNU.
    set_target_properties(${lib_name} PROPERTIES PREFIX "")
    set_target_properties(${lib_name}
        PROPERTIES
        ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin/$<CONFIG>"
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin/$<CONFIG>"
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin/$<CONFIG>")

    string(TOLOWER "${lib_type}" lib_type_lower)
    if(${lib_type_lower} STREQUAL "shared")
        # Issue strip command command
        if(CMAKE_STRIP AND CMAKE_BUILD_TYPE STREQUAL "Release")
            add_custom_command(TARGET ${lib_name} POST_BUILD
                COMMAND ${CMAKE_STRIP} --strip-unneeded $<TARGET_FILE:${lib_name}>
                WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
                COMMENT "Stripping library ${lib_name}"
                VERBATIM)
        endif()
    endif()

    if (WIN32)
        set(res_file "${CMAKE_CURRENT_LIST_DIR}/${lib_name}.rc")
        if(EXISTS ${res_file})
            message("--== Using resource file: ${res_file}")
            if("${CMAKE_C_COMPILER_ID}" STREQUAL "MSVC")
                target_sources(${lib_name} PRIVATE ${res_file})
            elseif("${CMAKE_C_COMPILER_ID}" STREQUAL "Clang")
                target_sources(${lib_name} PRIVATE ${res_file})
                set_source_files_properties(${res_file} PROPERTIES LANGUAGE RC)
            else()
                message("--== Resource compilation not supported for '${CMAKE_C_COMPILER_ID}'")
            endif()
        endif()
    endif()
endfunction()


macro(add_global_definitions)
    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
        add_definitions(-D_DEBUG -DDEBUG)
    else()
        add_definitions(-DNDEBUG -DVPN_SPEED)
    endif()

    if(CMAKE_SIZEOF_VOID_P EQUAL 8)
        set(COMPILER_ARCHITECTURE "x64")
        add_definitions(-DCPU_64)
    else()
        set(COMPILER_ARCHITECTURE "x86")
    endif()

    add_definitions(-D_REENTRANT -DREENTRANT -D_THREAD_SAFE -D_THREADSAFE -DTHREAD_SAFE -DTHREADSAFE -D_FILE_OFFSET_BITS=64)

    if(WIN32)
        add_definitions(-DWIN32 -D_WINDOWS -D_CRT_SECURE_NO_WARNINGS)
    endif()

    if(UNIX)
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fsigned-char")
        set(CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG} -g")
        set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} -O2")

        add_definitions(-DUNIX)

        if(${CMAKE_SYSTEM_NAME} STREQUAL "Linux")
            add_definitions(-DUNIX_LINUX)
            if("$ENV{USE_MUSL}" STREQUAL "YES")
                add_definitions(-DUNIX_LINUX_MUSL)
            endif()
        endif()

        if(${CMAKE_SYSTEM_NAME} STREQUAL "FreeBSD")
            add_definitions(-DUNIX_BSD -DBRIDGE_BPF)
            include_directories(SYSTEM /usr/local/include)
            link_directories(SYSTEM /usr/local/lib)
        endif()

        if(${CMAKE_SYSTEM_NAME} STREQUAL "OpenBSD")
            add_definitions(-DUNIX_BSD -DUNIX_OPENBSD)
            include_directories(SYSTEM /usr/local/include)
            link_directories(SYSTEM /usr/local/lib)
        endif()

        if(${CMAKE_SYSTEM_NAME} STREQUAL "SunOS")
            add_definitions(-DUNIX_SOLARIS -DNO_VLAN)
        endif()

        if(${CMAKE_SYSTEM_NAME} STREQUAL "Darwin")
            add_definitions(-DUNIX_BSD -DUNIX_MACOS -DBRIDGE_PCAP)
        endif()

        # Custom db, log, pid directory for Unix
        set(SE_DBDIR "" CACHE STRING "Directory where config files are saved")
        set(SE_LOGDIR "" CACHE STRING "Directory where log files are written")
        set(SE_PIDDIR "" CACHE STRING "Directory where PID files are put")

        if(SE_DBDIR)
            add_definitions(-DSE_DBDIR="${SE_DBDIR}")
        endif()

        if(SE_LOGDIR)
            add_definitions(-DSE_LOGDIR="${SE_LOGDIR}")
        endif()

        if(SE_PIDDIR)
            add_definitions(-DSE_PIDDIR="${SE_PIDDIR}")
        endif()
    endif()
endmacro()


# On Unix systems
macro(unix_print_install)
    if(UNIX)
        # Print message after installing the targets
        install(CODE "message(\"\n------------------------------------------------------------\")")
        install(CODE "message(\"Build completed successfully.\n\")")
        install(CODE "message(\"Execute 'vpnserver start' to run the SoftEther VPN Server background service.\")")
        install(CODE "message(\"Execute 'vpnbridge start' to run the SoftEther VPN Bridge background service.\")")
        install(CODE "message(\"Execute 'vpnclient start' to run the SoftEther VPN Client background service.\")")
        install(CODE "message(\"Execute 'vpncmd' to run the SoftEther VPN Command-Line Utility to configure VPN Server, VPN Bridge or VPN Client.\")")
        install(CODE "message(\"------------------------------------------------------------\n\")")
    endif()
endmacro()
