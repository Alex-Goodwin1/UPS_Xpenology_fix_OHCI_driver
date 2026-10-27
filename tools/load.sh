#!/bin/sh
# SPDX-License-Identifier: MIT
# Ручное управление модулями (без установки юнита). Ничего не пишет в систему.
#   DIR=/volume1/ohci-hcd sh load.sh verify|load|unload|status
DIR=${DIR:-/volume1/ohci-hcd}
HCD=$DIR/ohci-hcd.ko
PCI=$DIR/ohci-pci.ko

vmagic() { modinfo -F vermagic "$1" 2>/dev/null | awk '{print $1}'; }

verify() {
  rc=0
  for f in "$HCD" "$PCI"; do
    if [ ! -f "$f" ]; then echo "НЕТ ФАЙЛА: $f"; rc=1; continue; fi
    v=$(vmagic "$f")
    printf '%-14s vermagic=%-12s depends=%s\n' "$(basename "$f")" "$v" "$(modinfo -F depends "$f" 2>/dev/null)"
    if [ "$v" != "$(uname -r)" ]; then echo "  !! vermagic не совпадает с ядром $(uname -r)"; rc=1; fi
  done
  grep -q '^usbcore ' /proc/modules && echo "usbcore: загружен (не трогаем)" || { echo "usbcore: НЕ загружен"; rc=1; }
  lsmod | grep -q '^ohci_hcd' && echo "примечание: ohci_hcd уже загружен"
  [ "$rc" = "0" ] && echo "VERIFY OK" || echo "VERIFY FAILED"
  return $rc
}

load() {
  verify || { echo "загрузка отменена"; return 1; }
  echo "--- insmod ohci-hcd.ko"; insmod "$HCD" || return 1
  echo "--- insmod ohci-pci.ko";  insmod "$PCI" || { rmmod ohci_hcd 2>/dev/null; return 1; }
  sleep 2
  dmesg | tail -20
  status
}

unload() {
  if lsmod | grep -q '^ohci_pci'; then echo "rmmod ohci_pci"; rmmod ohci_pci; fi
  if lsmod | grep -q '^ohci_hcd'; then echo "rmmod ohci_hcd"; rmmod ohci_hcd; fi
  status
}

status() {
  echo "--- lsmod:"; lsmod | grep -i ohci || echo "   (не загружен)"
  echo "--- драйверы ohci:"; ls /sys/bus/pci/drivers | grep -i ohci || echo "   (нет)"
  echo "--- привязанные устройства:"
  for d in /sys/bus/pci/drivers/ohci-pci/0000:*; do [ -e "$d" ] && echo "   $(basename "$d")"; done
  echo "--- usb:"; ls /sys/bus/usb/devices
  echo "--- dmesg:"; dmesg | grep -iE 'ohci|low-speed|full-speed' | tail -10
}

case "$1" in
  verify) verify ;;
  load)   load ;;
  unload) unload ;;
  status) status ;;
  *) echo "использование: verify|load|unload|status  (DIR=$DIR)"; exit 1 ;;
esac
