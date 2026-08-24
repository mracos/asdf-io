#!/usr/bin/env bats
# Regression: the real bin/install driven end to end with git/cmake/make/io
# stubbed. Proves the whole install script (clone, addons patch, flag assembly,
# eerie step) behaves, not just the lib functions. Offline, no toolchain.

load ../helpers

setup() { setup_sandbox; }
teardown() { teardown_sandbox; }

cmake_args() { cat "$CMAKE_ARGS_LOG"; }
io_args() { cat "$IO_ARGS_LOG"; }

@test "clones the requested version and comments out the addons subdir" {
    run_install 2019.05.22-alpha
    [ "$status" -eq 0 ]

    run cat "$GIT_ARGS_LOG"
    [[ "$output" == *"--branch 2019.05.22-alpha"* ]]
    [[ "$output" == *"--recursive"* ]]

    run cat "$(io_source_dir)/CMakeLists.txt"
    [[ "$output" == *"#add_subdirectory(addons)"* ]]
}

@test "fixes the upstream garbagecollector target typo" {
    run_install 2015.11.11
    [ "$status" -eq 0 ]

    run cat "$(io_source_dir)/libs/CMakeLists.txt"
    [[ "$output" == *"garbagecollector"* ]]
    [[ "$output" != *"garabagecollector"* ]]
}

@test "swaps the glibc-removed sys/sysctl.h include on Linux" {
    export IO_OS=Linux
    run_install 2019.05.22-alpha
    [ "$status" -eq 0 ]

    run cat "$(io_source_dir)/libs/iovm/source/IoSystem.c"
    [[ "$output" != *"include <sys/sysctl.h>"* ]]
    [[ "$output" == *"include <unistd.h>"* ]]
}

@test "leaves the sys/sysctl.h include alone on macOS" {
    run_install 2019.05.22-alpha
    [ "$status" -eq 0 ]

    run cat "$(io_source_dir)/libs/iovm/source/IoSystem.c"
    [[ "$output" == *"include <sys/sysctl.h>"* ]]
}

@test "passes the core cmake flags including the CMP0042 build fix" {
    run_install 2019.05.22-alpha
    [ "$status" -eq 0 ]

    run cmake_args
    [[ "$output" == *"-DCMAKE_INSTALL_PREFIX=$WORK_DIR/install"* ]]
    [[ "$output" == *"-DCMAKE_BUILD_TYPE=release"* ]]
    [[ "$output" == *"-DCMAKE_POLICY_DEFAULT_CMP0042=NEW"* ]]
    [[ "$output" == *"-DWITHOUT_EERIE=1"* ]]
    [[ "$output" == *"-DCMAKE_INSTALL_RPATH=$WORK_DIR/install/lib"* ]]
}

@test "adds legacy clang flags for versions before 2017.09.06" {
    run_install 2015.11.11
    run cmake_args
    [[ "$output" == *"-DCMAKE_C_FLAGS=-Wno-implicit-function-declaration"* ]]
}

@test "no legacy clang flags for 2017.09.06 and later" {
    run_install 2019.05.22-alpha
    run cmake_args
    [[ "$output" != *"CMAKE_C_FLAGS"* ]]
}

@test "cross-compiles to x86_64 on arm64 hosts" {
    export IO_HOST_ARCH=arm64
    run_install 2019.05.22-alpha
    run cmake_args
    [[ "$output" == *"-DCMAKE_OSX_ARCHITECTURES='x86_64'"* ]]
}

@test "no osx arch flag on x86_64 hosts" {
    export IO_HOST_ARCH=x86_64
    run_install 2019.05.22-alpha
    run cmake_args
    [[ "$output" != *"CMAKE_OSX_ARCHITECTURES"* ]]
}

@test "installs eerie for versions that ship it, dropping docio" {
    run_install 2019.05.22-alpha
    [ "$status" -eq 0 ]

    run io_args
    [[ "$output" == *"setup.io"* ]]
    [[ "$output" == *"-dev"* ]]

    run cat "$(io_source_dir)/eerie/package.json"
    [[ "$output" != *"docio"* ]]
    [[ "$output" == *"kano.git"* ]]
}

@test "does not install eerie for versions before 2019.05.22-alpha" {
    run_install 2015.11.11
    [ "$status" -eq 0 ]
    run io_args
    [ -z "$output" ]
}

@test "WITHOUT_EERIE=1 skips eerie on a supported version" {
    export WITHOUT_EERIE=1
    run_install 2019.05.22-alpha
    [ "$status" -eq 0 ]
    run io_args
    [ -z "$output" ]
}

@test "leaves an existing ~/.eerie untouched" {
    mkdir -p "$HOME/.eerie"
    run_install 2019.05.22-alpha
    [ "$status" -eq 0 ]
    run io_args
    [ -z "$output" ]
}
