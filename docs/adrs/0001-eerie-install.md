# 0001 - Installing eerie on a modern toolchain

## Status

Accepted

## Context

Issue #3 asked to install [eerie](https://github.com/IoLanguage/eerie), the Io
package manager, by default. eerie ships as a submodule from `2019.05.22-alpha`
onward, and upstream wires its install into the Io build:

```cmake
# tools/CMakeLists.txt, guarded by if(NOT WITHOUT_EERIE)
add_custom_command(TARGET io POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_SOURCE_DIR}/eerie ${CMAKE_BINARY_DIR})
install(SCRIPT "${CMAKE_SOURCE_DIR}/InstallEerie.cmake")   # runs `io setup.io`
```

Enabling that path (dropping the plugin's long-standing `-DWITHOUT_EERIE=1`)
fails on a current toolchain. The failure chain, found by building end to end:

1. `copy_directory ${SOURCE}/eerie ${SOURCE}` overlaps its own destination in an
   in-source build; modern cmake rejects it.
2. eerie's `setup.io` builds its default dependency `docio`, whose `Markdown`
   addon needs the `discount` library (`mkdio.h`) — absent by default.
3. Even with `discount` installed, eerie's `Markdown` addon does not compile
   against discount 3.x: it was written for the old int-bitmask flag API, and
   discount 3.x made `mkd_flag_t` a pointer. This is an upstream eerie bug,
   unfixable from this plugin.
4. `setup.io` raises if `~/.eerie` already exists, so it is not idempotent.

## Decision

Do not use upstream's eerie build step. Keep `-DWITHOUT_EERIE=1` in the cmake
build always, and install eerie ourselves after `make install`:

- Drop the `docio` dependency from `eerie/package.json`. docio is a
  documentation generator; eerie's core package manager never references it at
  runtime (verified by grep of `eerie/io/`), so dropping it removes the broken
  Markdown chain while keeping a working package manager.
- Run `io setup.io -dev`, which installs eerie from the local submodule instead
  of cloning from the network and hitting the same broken default.
- Guard on `~/.eerie` for idempotency, and make the whole step best-effort: any
  failure is reported but never fails the Io install.

Enabled by default for supported versions; opt out with `WITHOUT_EERIE=1`. The
logic lives in `lib/eerie.bash`.

## Consequences

- eerie installs and its CLI works on a modern toolchain (`eerie -v`, `eerie
  envs`, `eerie envs` verified).
- `docio` (documentation generation) is not installed. The package manager, its
  environments, and package install/remove/update are unaffected.
- Installing eerie fetches `kano` from the network and writes a single per-user
  `~/.eerie` shared across Io versions; a second install leaves it as-is.
- `WITH_IO_ADDONS` (the pre-2019 addons path) is unrelated and unchanged.
