#!/usr/bin/env bash
# Convenience wrapper around the escape32-builder Docker image.
#
# Usage:
#   ./build.sh image              Build/rebuild the builder image
#   ./build.sh configure          Run `cmake -B build` (first time, or after CMakeLists.txt changes)
#   ./build.sh make [args...]     Run `make -C build [args...]` (every rebuild after configure)
#   ./build.sh shell              Drop into an interactive shell with the repo mounted
#
# Always operates on the repo this docker/ directory lives in.
#
# Examples:
#   ./build.sh image
#   ./build.sh configure
#   ./build.sh make
#   ./build.sh make flash-AART1
#   ./build.sh shell

set -euo pipefail

IMAGE_NAME="escape32-builder"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cmd="${1:-}"
shift || true

case "$cmd" in
  image)
    docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
    ;;
  configure)
    docker run --rm \
      -v "$REPO_ROOT:/workspace" \
      --user "$(id -u):$(id -g)" \
      "$IMAGE_NAME" bash -c 'cmake -B build -D LIBOPENCM3_DIR=$LIBOPENCM3_DIR'
    ;;
  make)
    docker run --rm \
      -v "$REPO_ROOT:/workspace" \
      --user "$(id -u):$(id -g)" \
      "$IMAGE_NAME" make -C build "$@"
    ;;
  shell)
    docker run --rm -it \
      -v "$REPO_ROOT:/workspace" \
      --user "$(id -u):$(id -g)" \
      "$IMAGE_NAME" bash
    ;;
  *)
    echo "Usage: $0 {image|configure|make [make-args...]|shell}" >&2
    exit 1
    ;;
esac
