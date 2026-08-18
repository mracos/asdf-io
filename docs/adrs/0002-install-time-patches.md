# 0002 - Install-time patches for toolchain drift

## Status

Accepted

## Context

Io releases are git tags from 2013-2019; they cannot be fixed upstream. The
toolchain keeps moving underneath them: CMake 4 dropped 2.8 compatibility,
clang 16 promoted old C laxness to errors, GCC's default inline model changed,
and glibc 2.32 removed `<sys/sysctl.h>`. The weekly integration job exists to
catch exactly this drift (first Linux run caught two of the entries below).

The plugin therefore adapts the build at install time. Two mechanisms, in
order of preference:

1. **cmake flags** (`lib/cmake.bash`, `io_cmake_flags`): when the problem can
   be solved by configuring or instructing the compiler.
2. **source seds** (`bin/install`, after clone): when the source itself is
   invalid for the current toolchain and no flag can express the fix.

## Decision

Keep a single catalog of every accommodation here; the how/why detail lives as
comments next to each patch in the code.

### cmake flags

| Flag | Versions | Why |
| ---- | -------- | --- |
| `-DCMAKE_POLICY_DEFAULT_CMP0042=NEW` | all | pre-2017.09.06 dylibs get an absolute install name and `io` can't find libiovmall at runtime; no-op for newer versions |
| `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` | all | CMake 4 refuses the `cmake_minimum_required(2.8)` every tag pins |
| `-DWITHOUT_EERIE=1` | all | upstream's eerie install step is broken on modern cmake; see [ADR 0001](0001-eerie-install.md) |
| `-Wno-implicit-function-declaration -Wno-int-conversion -Wno-implicit-int` | < 2017.09.06 | clang 16+ makes these hard errors; the old C sources trip all three |
| `-fgnu89-inline` | < 2017.09.06 | sources rely on gnu89 `extern inline`; GCC's C99+ model emits an external definition per translation unit and the link fails with `multiple definition of List_*` |
| `-DCMAKE_OSX_ARCHITECTURES='x86_64'` | arm64 hosts | upstream's documented macOS build instruction |

### source seds

| Patch | Versions | Why |
| ----- | -------- | --- |
| comment out `add_subdirectory(addons)` | all (unless `WITH_IO_ADDONS`) | addons moved out of the main repo after 2019.05.22-alpha; eerie owns them now |
| `garabagecollector` -> `garbagecollector` in `libs/CMakeLists.txt` | <= 2015.11.11 (no-op later) | upstream typo; CMake 4 fails generate on the unknown target |
| `include <sys/sysctl.h>` -> `include <unistd.h>` under `libs/` | all, Linux only | glibc 2.32 removed the header; every `sysctl()` call is guarded by `CTL_HW`/`HW_*` (defined by that same header) with a `sysconf()` fallback, so the Linux build never needed it. Upstream master ended up with plain `<unistd.h>` too |

OS-conditional patches gate on `io_os()` (`uname -s` with an `IO_OS` env
override), mirroring `io_host_arch()`/`IO_HOST_ARCH`, so the hermetic tests
can exercise both branches from any host.

## Consequences

- Old tags keep building on current macOS and Linux runners without forking
  upstream.
- Each patch is scoped to the versions and OS that need it and is a no-op
  elsewhere, so a future upstream release that fixes itself needs no change
  here.
- Any new drift failure from the weekly job should land as a new row in one
  of these tables, plus a regression test in `test/regression/install.bats`
  driven through the real `bin/install`.
