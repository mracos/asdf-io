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

@test "io_eerie_supported: true from 2019.05.22-alpha onward, false before" {
    io_eerie_supported 2019.05.22-alpha
    io_eerie_supported 2026.04.20-native-final
    ! io_eerie_supported 2017.09.06
    ! io_eerie_supported 2015.11.11
}

@test "io_host_arch: honors the IO_HOST_ARCH override" {
    IO_HOST_ARCH=arm64 run io_host_arch
    [ "$output" = "arm64" ]

    IO_HOST_ARCH=x86_64 run io_host_arch
    [ "$output" = "x86_64" ]
}

@test "io_os: honors the IO_OS override" {
    IO_OS=Linux run io_os
    [ "$output" = "Linux" ]

    IO_OS=Darwin run io_os
    [ "$output" = "Darwin" ]
}

@test "io_cmake_flags: always sets the install prefix and release build" {
    run io_cmake_flags 2017.09.06 /opt/io x86_64
    [ "$status" -eq 0 ]
    [[ "$output" == *"-DCMAKE_INSTALL_PREFIX=/opt/io"* ]]
    [[ "$output" == *"-DCMAKE_BUILD_TYPE=release"* ]]
}

@test "io_cmake_flags: adds the osx arch flag only on arm64" {
    run io_cmake_flags 2017.09.06 /opt/io arm64
    [[ "$output" == *"-DCMAKE_OSX_ARCHITECTURES='x86_64'"* ]]

    run io_cmake_flags 2017.09.06 /opt/io x86_64
    [[ "$output" != *"CMAKE_OSX_ARCHITECTURES"* ]]
}

@test "io_cmake_flags: forces CMP0042 so pre-2017.09.06 versions build" {
    run io_cmake_flags 2017.09.06 /opt/io x86_64
    [[ "$output" == *"-DCMAKE_POLICY_DEFAULT_CMP0042=NEW"* ]]
}

@test "io_cmake_flags: raises the policy floor so CMake 4 can configure" {
    run io_cmake_flags 2017.09.06 /opt/io x86_64
    [[ "$output" == *"-DCMAKE_POLICY_VERSION_MINIMUM=3.5"* ]]
}

@test "io_cmake_flags: downgrades modern-clang errors for pre-2017.09.06 sources" {
    run io_cmake_flags 2015.11.11 /opt/io x86_64
    [[ "$output" == *"-DCMAKE_C_FLAGS=-Wno-implicit-function-declaration"* ]]
}

@test "io_cmake_flags: forces gnu89 inline semantics for pre-2017.09.06 sources" {
    run io_cmake_flags 2015.11.11 /opt/io x86_64
    [[ "$output" == *"-fgnu89-inline"* ]]
}

@test "io_cmake_flags: no legacy C flags for 2017.09.06 and later" {
    run io_cmake_flags 2017.09.06 /opt/io x86_64
    [[ "$output" != *"CMAKE_C_FLAGS"* ]]

    run io_cmake_flags 2019.05.22-alpha /opt/io x86_64
    [[ "$output" != *"CMAKE_C_FLAGS"* ]]
}

@test "io_cmake_flags: always disables eerie in the cmake build" {
    run io_cmake_flags 2019.05.22-alpha /opt/io x86_64
    [[ "$output" == *"-DWITHOUT_EERIE=1"* ]]

    run io_cmake_flags 2015.11.11 /opt/io x86_64
    [[ "$output" == *"-DWITHOUT_EERIE=1"* ]]
}

@test "io_cmake_flags: sets an install RPATH pointing at the installed libs" {
    run io_cmake_flags 2019.05.22-alpha /opt/io x86_64
    [[ "$output" == *"-DCMAKE_INSTALL_RPATH=/opt/io/lib"* ]]

    run io_cmake_flags 2015.11.11 /opt/io x86_64
    [[ "$output" == *"-DCMAKE_INSTALL_RPATH=/opt/io/lib"* ]]
}
