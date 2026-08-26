# ESCape32 firmware build environment

A pinned, reproducible Docker build environment for this repo. The image
carries the toolchain only — `cmake`, the official ARM GNU Toolchain
(`arm-none-eabi-gcc`/`binutils`/`newlib`), and a prebuilt `libopencm3` — so it
stays valid across branches and firmware revisions. Firmware source is
mounted in at container-run time, not baked into the image.

**Validated:** both `Dockerfile` and `Dockerfile.arch` build, and a full
firmware build through each (`cmake -B build` + `make -C build`, all 43
targets, output owned by the calling user) tested end to end on Linux against
this repo's actual source (2026-08-26). Not yet exercised on macOS.

## Why mount instead of `COPY`

If the source were `COPY`'d into the image, you'd rebuild the entire image
(re-downloading the toolchain and rebuilding libopencm3) every time you
changed a line of firmware code. Mounting means: build the image once, then
every `docker run` against your checkout takes seconds.

## What's pinned, and why it matters

`libopencm3` is checked out to a fixed commit (set via the `LIBOPENCM3_REF`
build arg) rather than always pulling `master`, so two builds of the same
firmware source — whether that's you today and you in six months, or two
people, or two CI runs — produce equivalent output.

The compiler matters too: Ubuntu 24.04's packaged `gcc-arm-none-eabi`
(13.2.1) generates code that overflows ROM by a few hundred bytes on this
repo's flash-constrained STM32F051 targets (confirmed on `FLYCOLOR1` and
`EMAX1` while testing this image). This repo's own `.github/workflows/build.yml`
CI avoids that by using `carlosperate/arm-none-eabi-gcc-action`, which pulls
the official ARM GNU Toolchain release rather than the distro package — so
this Dockerfile does the same thing (pinned to `14.2.rel1`) instead of
`apt install`ing the compiler. All 43 targets build clean with it.

## Usage

Build the image once:
```bash
cd docker
docker build -t escape32-builder .
```

Or via the wrapper script, from the repo root:
```bash
./docker/build.sh image
```

Then, from the repo root:
```bash
# First time, or whenever CMakeLists.txt changes:
./docker/build.sh configure

# Every rebuild after that (editing src/*.c etc.), faster, no reconfigure:
./docker/build.sh make

# Build/flash one target specifically (pass-through args go to `make -C build`):
./docker/build.sh make AART1-rev17.1.elf
./docker/build.sh make flash-AART1
```

`build.sh` always mounts the repo it lives in (no path argument needed) and
runs as your own `uid:gid`, so `build/` — and everything in it — comes out
owned by you on the host, not root.

Equivalent raw `docker run` commands, if you'd rather not use the script:
```bash
docker run --rm -v "$(pwd):/workspace" --user "$(id -u):$(id -g)" escape32-builder \
  bash -c "cmake -B build -D LIBOPENCM3_DIR=\$LIBOPENCM3_DIR && make -C build"

docker run --rm -v "$(pwd):/workspace" --user "$(id -u):$(id -g)" escape32-builder \
  make -C build
```

ESCape32 itself is CMake-based; there's no plain `Makefile` at the repo root,
only inside `build/` after `cmake -B build` generates one. So a bare `make`
run from the repo root (rather than `make -C build`) fails with "No targets
specified and no makefile found" — that's expected, not a sign anything's
broken. `build.sh`'s `make` subcommand already runs `make -C build` for you.

## Flashing from inside the container

`stlink-tools` is included, but Docker doesn't see USB devices by default. On
Linux, add `--device=/dev/ttyACM0` (or whatever your ST-LINK shows up as) to
the `docker run` invocations, or just run `make -C build flash-<target>` on
the host instead — the container is really for the cross-compile step,
flashing is a one-line addition if you want it but not essential.

## Bumping the toolchain or libopencm3 pin

```bash
docker build -t escape32-builder \
  --build-arg LIBOPENCM3_REF=<new-commit-or-tag> \
  --build-arg ARM_TOOLCHAIN_VERSION=<new-version> \
  docker
```

Worth re-testing all targets afterward (especially the flash-constrained
STM32F051 ones) rather than treating a version bump as a side effect of an
unrelated change — code size right at the edge of flash is exactly where
compiler version differences bite.

## Ubuntu vs. Arch base

`Dockerfile` (Ubuntu 24.04) is the default and the one the GitHub Actions
workflows use.

`Dockerfile.arch` is an Arch Linux alternative, pinned to a specific Arch
Linux Archive snapshot date so it doesn't drift the way a bare `pacman -Syu`
would on a rolling-release distro. It installs the same official ARM GNU
Toolchain tarball as the Ubuntu image (not Arch's own package), so the two
should produce equivalent output. Both have been build-tested end to end,
including all 43 targets fitting flash.

To use it instead, build with `-f Dockerfile.arch` (or swap the filenames)
and everything else — `build.sh`, the GitHub Actions workflows — works
unchanged.

## Files

- `Dockerfile` — the build environment image (Ubuntu-based, default, tested).
- `Dockerfile.arch` — Arch Linux alternative, pinned via Arch Linux Archive (tested).
- `build.sh` — convenience wrapper for building the image and running it against this repo.
