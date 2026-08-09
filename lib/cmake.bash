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

# Host architecture, used to decide the macOS cross-compile flag. Overridable
# via IO_HOST_ARCH so tests and CI can exercise both branches on any host.
io_host_arch() {
    printf '%s\n' "${IO_HOST_ARCH:-$(/usr/bin/arch)}"
}

# Whether a version ships the eerie submodule we can install (see lib/eerie.bash).
# Eerie became a top-level submodule in 2019.05.22-alpha; before that it lived
# under addons with a different layout. Versions are date-based, so a lexical
# compare of the date prefix matches chronological order. Returns 0 (yes) / 1 (no).
io_eerie_supported() {
    [[ ! "$(io_version_date "$1")" < "2019.05.22" ]]
}

# Emit the cmake flags for an install, one per line.
#   $1 version       ASDF_INSTALL_VERSION
#   $2 install_path  ASDF_INSTALL_PATH
#   $3 arch          output of /usr/bin/arch (e.g. arm64)
io_cmake_flags() {
    local version="$1" install_path="$2" arch="$3"

    printf '%s\n' "-DCMAKE_INSTALL_PREFIX=${install_path}"
    printf '%s\n' "-DCMAKE_BUILD_TYPE=release"

    # Versions before 2017.09.06 predate the upstream `cmake_policy(SET CMP0042 NEW)`
    # and build the dylibs with an absolute install name, so the `io` binary can't
    # find libiovmall at runtime and even `io --version` fails. Force the RPATH
    # policy so those versions build and run; newer versions set it themselves, so
    # this is a no-op for them.
    printf '%s\n' "-DCMAKE_POLICY_DEFAULT_CMP0042=NEW"

    # eerie's own cmake install step (a copy_directory that overlaps its source,
    # plus a setup.io run) is broken on modern cmake, so always disable it here.
    printf '%s\n' "-DWITHOUT_EERIE=1"

    # clang 16+ promotes implicit function/int declarations and int<->pointer
    # conversions from warnings to hard errors, which the pre-2017.09.06 C
    # sources trip over at compile time. Downgrade them back to warnings for
    # those versions so they build under a modern toolchain; upstream's decade-old
    # source can't be patched from here. Newer versions compile clean, so the flag
    # is scoped to the versions that need it.
    if [[ "$(io_version_date "$version")" < "2017.09.06" ]]; then
        printf '%s\n' "-DCMAKE_C_FLAGS=-Wno-implicit-function-declaration -Wno-int-conversion -Wno-implicit-int"
    fi

    # see: https://github.com/IoLanguage/io/blob/master/README.md#macos-build-instructions
    if [[ "$arch" == "arm64" ]]; then
        printf '%s\n' "-DCMAKE_OSX_ARCHITECTURES='x86_64'"
    fi
}
