# asdf-io

[![test](https://github.com/mracos/asdf-io/actions/workflows/test.yml/badge.svg)](https://github.com/mracos/asdf-io/actions/workflows/test.yml)

[Io](http://iolanguage.org/) plugin for [asdf](https://github.com/asdf-vm/asdf) version manager.

## Install

```
asdf plugin-add io https://github.com/mracos/asdf-io.git
```

## Use

Check [asdf](https://github.com/asdf-vm/asdf) readme for instructions on how to install & manage versions of Io.

## Eerie

For versions from `2019.05.22-alpha` on, the [eerie](https://github.com/IoLanguage/eerie) package manager is installed by default (older versions predate the eerie submodule). Opt out with `WITHOUT_EERIE=1`:

```
WITHOUT_EERIE=1 asdf install io $VERSION
```

Eerie's own build is broken on modern toolchains, so it is installed with a workaround: its `docio` documentation dependency is dropped (its Markdown addon no longer compiles against `discount` 3.x) and eerie is set up from the local submodule via `io setup.io -dev`. The core package manager is unaffected. See [docs/adrs/0001-eerie-install.md](docs/adrs/0001-eerie-install.md).

Notes:

- Installing eerie fetches `kano` over the network and writes a single per-user `~/.eerie` shared across Io versions; if it already exists it is left untouched.
- The step is best-effort: if eerie fails, the Io install still succeeds.
- After install, add `EERIEDIR` and eerie's `bin` dirs to your shell (the setup output prints a snippet), and make sure `io` is on your `PATH`.


## Addons
By default it does not build with the addons either, but you can pass a `WITH_IO_ADDONS` env var to the install command, e.g.
`WITH_IO_ADDONS=true asdf install io $VERSION`

:warning: for versions after (`2019.05.22-alpha`) the addons are now eerie packages, so the flag above will not work

please see [IoLanguage/io#400](https://github.com/IoLanguage/io/issues/400) for more information

Keeping in mind that you'll need the following packages if building with the addons
- [yajl](https://github.com/lloyd/yajl)
- [libevent](http://libevent.org/)
- [pcre](http://www.pcre.org/)
- [memcached](https://memcached.org/)
- [ode](http://www.ode.org/)
- [sqlite](http://www.sqlite.org/)

## Development

Tested with [bats](https://github.com/bats-core/bats-core) at three levels:

- `test/unit` — the pure helpers in `lib/*.bash`.
- `test/regression` — the real `bin/install` run end to end with `git`/`cmake`/`make`/`io` stubbed (offline, no toolchain).
- `test/integration` — a real `mise install io@<version>`; skipped unless `ASDF_IO_RUN_INTEGRATION=1`.

```
npm install                    # bats + shellcheck
npm test                       # unit + regression (fast, offline)
npm run lint                   # shellcheck
npm run test:integration       # real builds; needs mise + a network
```

On Apple Silicon the real build needs cmake 3.x on `PATH` (CMake 4 rejects Io's `cmake_minimum_required(2.8)`): `mise use cmake@3.31.6` first.
