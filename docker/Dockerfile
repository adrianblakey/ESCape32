# ESCape32 firmware build environment
#
# This image only contains the TOOLCHAIN (cmake, arm-none-eabi-gcc/binutils/newlib,
# and a prebuilt libopencm3). It does NOT contain any firmware source.
#
# Firmware source is mounted into /workspace at `docker run` time, so this image
# stays valid across branches and firmware versions — rebuild it only when you
# want to bump the toolchain or the libopencm3 pin, not every time firmware
# source changes.
#
# Build the image:
#   docker build -t escape32-builder .
#
# Use it against a checked-out copy of this repo:
#   docker run --rm -v "$(pwd):/workspace" escape32-builder \
#     bash -c "cmake -B build -D LIBOPENCM3_DIR=\$LIBOPENCM3_DIR && make -C build"
#
# Drop into a shell for interactive work:
#   docker run --rm -it -v "$(pwd):/workspace" escape32-builder bash

FROM ubuntu:24.04

# Pin libopencm3 to a known-good commit for reproducible builds. This is the
# exact commit this Dockerfile was build-tested against (2026-08-26).
# Bump with --build-arg LIBOPENCM3_REF=<commit-or-tag> when you want newer libopencm3.
ARG LIBOPENCM3_REF=2da12dc96e0b9e42a3332348dd9b02a0a17981f8

# Targets libopencm3 builds support files for. Covers every MCU family used
# across this repo's targets (AT32F421/GD32F350/STM32F051 -> stm32/f0,
# GD32E230/STM32G071 -> stm32/g0, STM32G431 -> stm32/g4, STM32L431 -> stm32/l4).
# Extend this if a future target lands on a different STM32 family (see mcu/*/config.h).
ARG LIBOPENCM3_TARGETS="stm32/f0 stm32/g0 stm32/g4 stm32/l4"

# Ubuntu 24.04's packaged gcc-arm-none-eabi (13.2.1) generates code just large
# enough to overflow ROM on this repo's flash-constrained STM32F051 targets
# (FLYCOLOR1, EMAX1 confirmed). Use the official ARM GNU Toolchain release
# instead -- it's also what this repo's own build.yml CI uses (via
# carlosperate/arm-none-eabi-gcc-action), so this matches known-good output.
ARG ARM_TOOLCHAIN_VERSION=14.2.rel1
ARG ARM_TOOLCHAIN_URL=https://developer.arm.com/-/media/Files/downloads/gnu/${ARM_TOOLCHAIN_VERSION}/binrel/arm-gnu-toolchain-${ARM_TOOLCHAIN_VERSION}-x86_64-arm-none-eabi.tar.xz

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        cmake \
        make \
        git \
        ca-certificates \
        curl \
        xz-utils \
        stlink-tools \
        python3 \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL "${ARM_TOOLCHAIN_URL}" -o /tmp/arm-toolchain.tar.xz \
    && mkdir -p /opt/arm-gnu-toolchain \
    && tar -xf /tmp/arm-toolchain.tar.xz -C /opt/arm-gnu-toolchain --strip-components=1 \
    && rm /tmp/arm-toolchain.tar.xz

ENV PATH="/opt/arm-gnu-toolchain/bin:${PATH}"

# Build libopencm3 once at image-build time so container startup is instant.
# python3 is required here: libopencm3 generates nvic.h/vector_nvic.c/irqhandlers.h
# per target family via irq2nvic_h, whose shebang is #!/usr/bin/env python3.
RUN git clone https://github.com/libopencm3/libopencm3.git /opt/libopencm3 \
    && cd /opt/libopencm3 \
    && git checkout "${LIBOPENCM3_REF}" \
    && make TARGETS="${LIBOPENCM3_TARGETS}" \
    && rm -rf /opt/libopencm3/.git

ENV LIBOPENCM3_DIR=/opt/libopencm3

WORKDIR /workspace

CMD ["bash"]
