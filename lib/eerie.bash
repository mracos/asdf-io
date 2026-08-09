#!/usr/bin/env bash
# Install the eerie package manager after Io is built.
#
# Upstream's own eerie install (a cmake `copy_directory` that overlaps its
# source, plus a setup.io run) breaks on modern cmake, and eerie's default
# `docio` dependency pulls in a Markdown addon that no longer compiles against
# discount 3.x. We sidestep both: disable eerie in the cmake build (see
# lib/cmake.bash), drop the docio dependency, and run setup.io in -dev mode
# against the local eerie submodule. eerie's core package manager never uses
# docio at runtime, so dropping it yields a working install.
#
# It is best-effort: any failure here is reported but never fails the Io
# install itself. See docs/adrs/0001-eerie-install.md.

# Drop the docio dependency from eerie's package.json, and clean up the now
# dangling trailing comma after the remaining (kano) entry.
io_eerie_drop_docio() {
    local pkg="$1/package.json"
    [[ -f "$pkg" ]] || return 0
    sed -i.bak '/docio\.git/d' "$pkg"
    sed -i.bak2 's/\(kano\.git"\)[[:space:]]*,/\1/' "$pkg"
    rm -f "$pkg.bak" "$pkg.bak2"
}

# Install eerie from the local submodule. Best-effort: returns 0 on any skip
# or failure so a broken eerie never fails the Io install.
#   $1 source_path   the cloned Io source (contains the eerie submodule)
#   $2 install_path  ASDF_INSTALL_PATH (holds bin/io)
io_install_eerie() {
    local source_path="$1" install_path="$2"

    [[ -d "$source_path/eerie" ]] || return 0

    # ~/.eerie is a single per-user install shared across Io versions, and
    # setup.io raises if it already exists. Leave an existing one untouched.
    if [[ -d "$HOME/.eerie" ]]; then
        echo "asdf-io: ~/.eerie already exists; leaving eerie as-is" >&2
        return 0
    fi

    io_eerie_drop_docio "$source_path/eerie"

    echo "asdf-io: installing the eerie package manager..." >&2
    if ( cd "$source_path/eerie" && "$install_path/bin/io" setup.io -dev ); then
        echo "asdf-io: eerie installed. Add EERIEDIR and eerie's bin dirs to your shell (see the setup output above)." >&2
    else
        echo "asdf-io: eerie setup failed; Io itself installed fine. Re-run with WITHOUT_EERIE=1 to skip eerie." >&2
    fi
    return 0
}
