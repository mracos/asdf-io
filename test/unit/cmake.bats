#!/usr/bin/env bats
# Unit tests for lib/cmake.bash — the cmake flag assembly behind bin/install.
# Fully offline: they call the real functions and assert the emitted flags,
# so a regression in the install logic fails here before it reaches a user.

load ../helpers

setup() {
    load_lib cmake
}

@test "io_version_date: strips the pre-release suffix" {
    [ "$(io_version_date 2019.05.22-alpha)" = "2019.05.22" ]
    [ "$(io_version_date 2026.04.20-native-final)" = "2026.04.20" ]
    [ "$(io_version_date 2017.09.06)" = "2017.09.06" ]
}

@test "io_cmake_flags: always sets the install prefix and release build" {
    run io_cmake_flags /opt/io x86_64
    [ "$status" -eq 0 ]
    [[ "$output" == *"-DCMAKE_INSTALL_PREFIX=/opt/io"* ]]
    [[ "$output" == *"-DCMAKE_BUILD_TYPE=release"* ]]
}

@test "io_cmake_flags: adds the osx arch flag only on arm64" {
    run io_cmake_flags /opt/io arm64
    [[ "$output" == *"-DCMAKE_OSX_ARCHITECTURES='x86_64'"* ]]

    run io_cmake_flags /opt/io x86_64
    [[ "$output" != *"CMAKE_OSX_ARCHITECTURES"* ]]
}

@test "io_cmake_flags: disables eerie" {
    run io_cmake_flags /opt/io x86_64
    [[ "$output" == *"-DWITHOUT_EERIE=1"* ]]
}
