#!/bin/sh
# SPDX-License-Identifier: MIT
# Сводка состояния: модули, шины, USB-устройства, UPS, юнит автозагрузки.
echo "===== OHCI / UPS status: $(date) ====="
echo "ядро: $(uname -r) $(uname -m)  ($(uname -v | cut -c1-40)...)"
echo
echo "-- модули:"
lsmod | grep -iE 'ohci|usbhid' || echo "   ohci не загружен"
echo
echo "-- привязка ohci-pci к PCI:"
found=0
for d in /sys/bus/pci/drivers/ohci-pci/0000:*; do
  [ -e "$d" ] || continue
  found=1
  echo "   $(basename "$d")  class=$(cat "$d/class")  irq=$(cat "$d/irq" 2>/dev/null)"
done
[ "$found" = "0" ] && echo "   (нет)"
echo
echo "-- USB-шины:"
for u in /sys/bus/usb/devices/usb*; do
  [ -e "$u" ] || continue
  printf '   %-5s %s\n' "$(basename "$u")" "$(cat "$u/product" 2>/dev/null)"
done
echo
echo "-- устройства на шинах (USB 1.1 / full-low speed):"
for d in /sys/bus/usb/devices/[0-9]*-[0-9]*; do
  [ -e "$d" ] || continue
  v=$(cat "$d/idVendor" 2>/dev/null) || continue
  [ -z "$v" ] && continue
  printf '   %-8s %s:%s  %-25s %s\n' "$(basename "$d")" "$v" "$(cat "$d/idProduct")" \
    "$(cat "$d/product" 2>/dev/null)" "$(cat "$d/manufacturer" 2>/dev/null)"
done
echo
echo "-- DSM UPS:"
if [ -x /usr/bin/upsc ]; then
  systemctl is-active ups-usb.service 2>/dev/null | sed 's/^/   ups-usb.service: /'
  /usr/bin/upsc ups 2>/dev/null | grep -E 'ups.status|battery.charge|battery.runtime|input.voltage|device.model|driver.name' | sed 's/^/   /' || echo "   нет данных от NUT"
else
  echo "   upsc не найден"
fi
echo
echo "-- автозагрузка:"
systemctl is-enabled ohci-ups.service 2>/dev/null | sed 's/^/   ohci-ups.service: /'
systemctl is-active ohci-ups.service 2>/dev/null | sed 's/^/   active: /'
echo "===== end ====="
