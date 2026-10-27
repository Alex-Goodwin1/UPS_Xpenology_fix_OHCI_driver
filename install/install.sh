#!/bin/sh
# SPDX-License-Identifier: MIT
# Установка ohci-hcd.ko / ohci-pci.ko на DSM (без изменения /usr/lib/modules и без depmod).
#   SRC=prebuilt/epyc7002-5.10.55+ sh install.sh
#   BASE=/volume1/ohci-hcd  — куда положить модули (по умолчанию)
set -e

HERE=$(cd "$(dirname "$0")" && pwd)
BASE=${BASE:-/volume1/ohci-hcd}
SRC=${SRC:-}

if [ "$(id -u)" != "0" ]; then echo "нужен root"; exit 1; fi

# где взять .ko
if [ -z "$SRC" ]; then
  for d in "$HERE/modules" "$HERE" "$HERE"/../prebuilt/*; do
    [ -f "$d/ohci-hcd.ko" ] && { SRC=$d; break; }
  done
fi
if [ -z "$SRC" ] || [ ! -f "$SRC/ohci-hcd.ko" ] || [ ! -f "$SRC/ohci-pci.ko" ]; then
  echo "не найдены ohci-hcd.ko/ohci-pci.ko. Укажите SRC=<каталог с .ko>"; exit 1
fi
echo "модули : $SRC"

# проверка vermagic
KVER=$(uname -r)
for m in ohci-hcd ohci-pci; do
  VM=$(modinfo -F vermagic "$SRC/$m.ko" 2>/dev/null | awk '{print $1}')
  if [ "$VM" != "$KVER" ]; then
    echo "ОШИБКА: $m.ko собран под '$VM', ядро '$KVER'."
    echo "Нужно пересобрать: IMAGE=auxxxilium/syno-compiler:<ver> PLATFORM=<platform> sh build/build-ohci.sh"
    exit 1
  fi
  printf '%-12s vermagic=%s  (kernel %s)\n' "$m.ko" "$VM" "$KVER"
done

mkdir -p "$BASE"
cp -f "$SRC/ohci-hcd.ko" "$SRC/ohci-pci.ko" "$BASE"/
chmod 644 "$BASE"/ohci-hcd.ko "$BASE"/ohci-pci.ko
for f in README.md; do
  [ -f "$HERE/../$f" ] && cp -f "$HERE/../$f" "$BASE/$f"
done
echo "скопировано в $BASE"

sed "s|__BASE__|$BASE|g" "$HERE/ohci-ups.service.template" > /etc/systemd/system/ohci-ups.service
systemctl daemon-reload
systemctl enable ohci-ups.service
echo "юнит установлен и включён"

if [ ! -d /sys/module/ohci_hcd ]; then
  echo "загружаем модули сейчас..."
  insmod "$BASE/ohci-hcd.ko"
  insmod "$BASE/ohci-pci.ko"
  sleep 2
else
  echo "ohci_hcd уже загружен — insmod не нужен"
fi

echo "--- lsmod:"; lsmod | grep -i ohci || true
echo "--- шины OHCI:"; ls /sys/bus/usb/devices 2>/dev/null | grep '^usb' | while read -r u; do
  echo "    $u $(cat /sys/bus/usb/devices/$u/product 2>/dev/null)"
done
echo "--- NUT:"; /usr/bin/upsc ups 2>/dev/null | grep -E 'ups.status|battery.charge|device.model|driver.name' || \
  echo "    нет данных (проверьте: systemctl start ups-usb.service)"
echo
echo "Готово. Проверка: sh tools/status.sh"
