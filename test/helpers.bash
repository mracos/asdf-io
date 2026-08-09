#!/usr/bin/env bash
# Shared bats helpers for asdf-io tests.

# Repo root, computed from this file's location.
export PLUGIN_DIR="${PLUGIN_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"

# Source a lib file into the current test's shell scope.
load_lib() {
    # shellcheck source=/dev/null
    source "$PLUGIN_DIR/lib/${1}.bash"
}
