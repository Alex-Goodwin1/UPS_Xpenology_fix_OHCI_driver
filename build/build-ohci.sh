#!/bin/sh
# SPDX-License-Identifier: MIT
# Сборка ohci-hcd.ko + ohci-pci.ko в контейнере auxxxilium/syno-compiler.
#   IMAGE=auxxxilium/syno-compiler:7.4 PLATFORM=epyc7002 sh build-ohci.sh
set -e

IMAGE=${IMAGE:-auxxxilium/syno-compiler:7.4}
PLATFORM=${PLATFORM:-epyc7002}
KERNEL_TARBALL=${KERNEL_TARBALL:-linux-5.10.x.txz}

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
SRC=${SRC:-$ROOT/src}
OUT=${OUT:-$ROOT/out}

# на DSM docker лежит в /usr/local/bin и не всегда есть в PATH
DOCKER=${DOCKER:-docker}
command -v "$DOCKER" >/dev/null 2>&1 || DOCKER=/usr/local/bin/docker

if [ ! -f "$SRC/$KERNEL_TARBALL" ]; then
  echo "нет $SRC/$KERNEL_TARBALL"
  echo "сначала: GPL_VER=<x.y-build> PLATFORM=$PLATFORM sh build/fetch-gpl-source.sh"
  exit 1
fi

mkdir -p "$OUT"
chmod 777 "$OUT" 2>/dev/null || true

echo "image    : $IMAGE"
echo "platform : $PLATFORM"
echo "docker   : $DOCKER"
echo "src      : $SRC/$KERNEL_TARBALL"
echo "out      : $OUT"

"$DOCKER" run --rm --name ohci-build-run \
  -e PLATFORM="$PLATFORM" \
  -e KERNEL_TARBALL="$KERNEL_TARBALL" \
  -v "$OUT:/output:rw" \
  -v "$SRC:/src:ro" \
  -v "$HERE:/kit:ro" \
  "$IMAGE" shell "$PLATFORM" /kit/in-container-build.sh
