#!/usr/bin/env bash
# Shared bats helpers for asdf-io tests.

# Repo root, computed from this file's location.
export PLUGIN_DIR="${PLUGIN_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"

# Source a lib file into the current test's shell scope.
load_lib() {
    # shellcheck source=/dev/null
    source "$PLUGIN_DIR/lib/${1}.bash"
}

# --- Hermetic install sandbox -------------------------------------------------
#
# bin/install talks to the network (git) and the build toolchain (cmake, make)
# and, for eerie, runs the freshly built `io`. setup_sandbox stands up a stub
# bin dir on a pinned PATH so the *real* bin/install runs end to end while every
# external command is a recording stub: no network, no compiler. Mirrors the
# approach in asdf-swiprolog.

setup_sandbox() {
    WORK_DIR="$(mktemp -dt asdf-io-test-XXXXXX)"
    export WORK_DIR
    export STUB_BIN="$WORK_DIR/bin"
    export HOME="$WORK_DIR/home"
    export TMPDIR="$WORK_DIR/tmp"           # so bin/install's mktemp lands here
    export GIT_ARGS_LOG="$WORK_DIR/git-args.log"
    export CMAKE_ARGS_LOG="$WORK_DIR/cmake-args.log"
    export IO_ARGS_LOG="$WORK_DIR/io-args.log"
    export SOURCE_PATH_LOG="$WORK_DIR/source-path"
    export IO_HOST_ARCH="x86_64"            # default host; tests opt into arm64
    mkdir -p "$STUB_BIN" "$HOME" "$TMPDIR"
    : > "$GIT_ARGS_LOG"
    : > "$CMAKE_ARGS_LOG"
    : > "$IO_ARGS_LOG"

    # git clone: record argv, then materialize a minimal Io source tree (a
    # CMakeLists with the addons line, plus an eerie submodule that declares a
    # docio dependency) so the rest of bin/install has something real to act on.
    cat > "$STUB_BIN/git" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "$GIT_ARGS_LOG"
dest=""
for dest; do :; done
[ -n "$dest" ] || exit 0
echo "$dest" > "$SOURCE_PATH_LOG"
mkdir -p "$dest/eerie" "$dest/libs"
printf 'add_subdirectory(addons)\n' > "$dest/CMakeLists.txt"
# Old versions carry the upstream `garabagecollector` typo; bin/install fixes it.
printf 'add_dependencies(iovmall_static io2c basekit coroutine garabagecollector iovmall)\n' > "$dest/libs/CMakeLists.txt"
cat > "$dest/eerie/package.json" <<'PJ'
{
  "dependencies": {
    "packages": [
        "https://github.com/IoLanguage/kano.git",
        "https://github.com/IoLanguage/docio.git"
    ]
  }
}
PJ
printf 'setup\n' > "$dest/eerie/setup.io"
exit 0
STUB

    # cmake records its argv so tests can assert on the flags.
    cat > "$STUB_BIN/cmake" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" >> "$CMAKE_ARGS_LOG"
STUB

    # make is a no-op; run_install seeds the io binary `make install` produces.
    printf '#!/usr/bin/env bash\nexit 0\n' > "$STUB_BIN/make"

    chmod +x "$STUB_BIN"/*
    export PATH="$STUB_BIN:/usr/bin:/bin:/usr/sbin:/sbin"
}

teardown_sandbox() {
    # Clean the mktemp download dir too, in case it landed outside WORK_DIR.
    if [[ -f "${SOURCE_PATH_LOG:-}" ]]; then
        local src
        src="$(cat "$SOURCE_PATH_LOG")"
        [[ -n "$src" ]] && rm -rf "$(dirname "$src")"
    fi
    [[ -n "${WORK_DIR:-}" && -d "$WORK_DIR" ]] && rm -rf "$WORK_DIR"
}

# run_install <version> — run the real bin/install against the sandbox. Seeds
# the io binary that `make install` would produce as a recording stub, so the
# eerie step's invocation of it is observable via IO_ARGS_LOG.
run_install() {
    export ASDF_INSTALL_TYPE=version
    export ASDF_INSTALL_VERSION="$1"
    export ASDF_INSTALL_PATH="$WORK_DIR/install"
    mkdir -p "$ASDF_INSTALL_PATH/bin"
    cat > "$ASDF_INSTALL_PATH/bin/io" <<'IOSTUB'
#!/usr/bin/env bash
printf '%s\n' "$@" >> "$IO_ARGS_LOG"
IOSTUB
    chmod +x "$ASDF_INSTALL_PATH/bin/io"
    run bash "$PLUGIN_DIR/bin/install"
}

# io_source_dir — the cloned Io source tree, as recorded by the git stub.
io_source_dir() {
    cat "$SOURCE_PATH_LOG" 2>/dev/null
}
