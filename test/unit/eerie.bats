#!/usr/bin/env bats
# Unit tests for lib/eerie.bash — the post-build eerie install.
# Offline: they exercise the package.json patch and the best-effort guards
# without running a real eerie setup (which needs a built io + network).

load ../helpers

setup() {
    load_lib eerie
}

@test "io_eerie_drop_docio: removes docio and leaves valid JSON deps" {
    local dir="$BATS_TEST_TMPDIR/eerie"
    mkdir -p "$dir"
    cat > "$dir/package.json" <<'JSON'
{
  "dependencies": {
    "packages": [
        "https://github.com/IoLanguage/kano.git",
        "https://github.com/IoLanguage/docio.git"
    ]
  }
}
JSON

    io_eerie_drop_docio "$dir"

    run cat "$dir/package.json"
    [[ "$output" != *"docio"* ]]
    [[ "$output" == *'kano.git"'* ]]
    [[ "$output" != *'kano.git",'* ]]
    [[ ! -f "$dir/package.json.bak" ]]
}

@test "io_eerie_drop_docio: no-op when package.json is missing" {
    run io_eerie_drop_docio "$BATS_TEST_TMPDIR/nope"
    [ "$status" -eq 0 ]
}

@test "io_install_eerie: no-op (exit 0) when the eerie submodule is absent" {
    local src="$BATS_TEST_TMPDIR/src"
    mkdir -p "$src"
    run io_install_eerie "$src" "/nonexistent"
    [ "$status" -eq 0 ]
}

@test "io_install_eerie: skips when ~/.eerie already exists" {
    local src="$BATS_TEST_TMPDIR/src"
    mkdir -p "$src/eerie"
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME/.eerie"

    run io_install_eerie "$src" "/nonexistent"
    [ "$status" -eq 0 ]
    [[ "$output" == *"already exists"* ]]
}
