#!/usr/bin/env bash
# Pure helpers for assembling the cmake invocation used by bin/install.
#
# bin/install and the bats unit tests both source this file, so the tests
# exercise the exact same logic that runs during an install (no
# reimplementation in tests). Keep this file side-effect free: define
# functions only, do no top-level work.

# Strip the pre-release suffix from an Io version, leaving the YYYY.MM.DD date.
#   2019.05.22-alpha -> 2019.05.22
io_version_date() {
    printf '%s\n' "${1%%-*}"
}

# Emit the cmake flags for an install, one per line.
#   $1 install_path  ASDF_INSTALL_PATH
#   $2 arch          output of /usr/bin/arch (e.g. arm64)
io_cmake_flags() {
    local install_path="$1" arch="$2"

    printf '%s\n' "-DCMAKE_INSTALL_PREFIX=${install_path}"
    printf '%s\n' "-DCMAKE_BUILD_TYPE=release"
    printf '%s\n' "-DWITHOUT_EERIE=1"

    # see: https://github.com/IoLanguage/io/blob/master/README.md#macos-build-instructions
    if [[ "$arch" == "arm64" ]]; then
        printf '%s\n' "-DCMAKE_OSX_ARCHITECTURES='x86_64'"
    fi
}
