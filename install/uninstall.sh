#!/bin/sh
# SPDX-License-Identifier: MIT
# Полное удаление: юнит + выгрузка модулей (+ каталог при PURGE=1).
set -e

BASE=${BASE:-/volume1/ohci-hcd}
PURGE=${PURGE:-0}

if [ "$(id -u)" != "0" ]; then echo "нужен root"; exit 1; fi

systemctl stop ohci-ups.service 2>/dev/null || true
systemctl disable ohci-ups.service 2>/dev/null || true
rm -f /etc/systemd/system/ohci-ups.service
systemctl daemon-reload
echo "юнит снят"

if lsmod | grep -q '^ohci_pci'; then rmmod ohci_pci && echo "rmmod ohci_pci"; fi
if lsmod | grep -q '^ohci_hcd'; then rmmod ohci_hcd && echo "rmmod ohci_hcd"; fi

if [ "$PURGE" = "1" ]; then
  rm -rf "$BASE"
  echo "каталог $BASE удалён"
fi

echo "--- lsmod:"; lsmod | grep -i ohci || echo "    (ohci не загружен)"
