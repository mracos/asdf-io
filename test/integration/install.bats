#!/usr/bin/env bats
# Integration: a real `mise install io@<version>` end to end (git clone + build).
# Slow and needs a network + a working toolchain, so it is skipped unless
# ASDF_IO_RUN_INTEGRATION=1. Run locally with:
#
#   ASDF_IO_RUN_INTEGRATION=1 npm run test:integration
#
# Note: on Apple Silicon the build needs cmake 3.x on PATH (CMake 4 rejects
# Io's `cmake_minimum_required(2.8)`); e.g. `mise use cmake@3.31.6` first.

setup_file() {
    [[ "${ASDF_IO_RUN_INTEGRATION:-0}" == "1" ]] \
        || skip "set ASDF_IO_RUN_INTEGRATION=1 to run integration tests"

    PLUGIN_DIR="$(cd -- "$(dirname -- "$BATS_TEST_FILENAME")/../.." && pwd)"
    export PLUGIN_DIR
    mise plugin uninstall io >/dev/null 2>&1 || true
    mise plugin link io "$PLUGIN_DIR" >&2
}

teardown_file() {
    [[ "${ASDF_IO_RUN_INTEGRATION:-0}" == "1" ]] || return 0
    mise uninstall -y io@2019.05.22-alpha >/dev/null 2>&1 || true
    mise uninstall -y io@2015.11.11 >/dev/null 2>&1 || true
}

@test "ls-remote lists known versions" {
    run mise ls-remote io
    [ "$status" -eq 0 ]
    [[ "$output" == *"2019.05.22-alpha"* ]]
}

@test "installs a pre-2017 version and it runs (CMP0042 + clang flags fix)" {
    WITHOUT_EERIE=1 mise install io@2015.11.11 >&2
    run mise exec io@2015.11.11 -- io --version
    [ "$status" -eq 0 ]
    [[ "$output" == *"Io Programming Language"* ]]
}

@test "installs a recent version with eerie and both run" {
    mise install io@2019.05.22-alpha >&2
    run mise exec io@2019.05.22-alpha -- io --version
    [ "$status" -eq 0 ]
    [[ "$output" == *"Io Programming Language"* ]]
}
