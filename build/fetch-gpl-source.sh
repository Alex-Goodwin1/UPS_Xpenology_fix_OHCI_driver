#!/bin/sh
# SPDX-License-Identifier: MIT
# Скачивает GPL-исходники ядра Synology для нужной сборки DSM.
#   PLATFORM=epyc7002 GPL_VER=7.4-90080 sh fetch-gpl-source.sh
set -e

PLATFORM=${PLATFORM:-epyc7002}
GPL_VER=${GPL_VER:-7.4-90080}
KSERIES=${KSERIES:-5.10}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DEST=${DEST:-$ROOT/src}
FILE="linux-${KSERIES}.x.txz"

URL="https://global.synologydownload.com/download/ToolChain/Synology%20NAS%20GPL%20Source/${GPL_VER}/${PLATFORM}/${FILE}"

mkdir -p "$DEST"
echo "platform : $PLATFORM"
echo "gpl ver  : $GPL_VER"
echo "dest     : $DEST/$FILE"
echo "url      : $URL"

if [ -s "$DEST/$FILE" ]; then
  echo "уже есть: $(ls -l "$DEST/$FILE" | awk '{print $5" байт"}')"
  exit 0
fi

curl -fL --retry 3 --retry-delay 2 -o "$DEST/$FILE.part" "$URL"
mv -f "$DEST/$FILE.part" "$DEST/$FILE"
echo "готово: $(ls -l "$DEST/$FILE" | awk '{print $5" байт"}')"
