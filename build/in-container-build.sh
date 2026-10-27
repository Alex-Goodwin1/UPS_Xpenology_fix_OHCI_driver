#!/bin/bash
# SPDX-License-Identifier: MIT
# Выполняется ВНУТРИ контейнера auxxxilium/syno-compiler (через `do.sh shell <platform>`).
# KSRC/CROSS_COMPILE уже экспортированы do.sh, PLATFORM/KERNEL_TARBALL приходят из -e.
set -e

PLATFORM=${PLATFORM:-epyc7002}
KERNEL_TARBALL=${KERNEL_TARBALL:-linux-5.10.x.txz}
BUILD=${KSRC:-/opt/$PLATFORM/build}
WORK=${WORK:-/work}

echo "== platform=$PLATFORM tarball=$KERNEL_TARBALL"
echo "== KSRC=$KSRC"
echo "== CROSS_COMPILE=$CROSS_COMPILE"

echo "== распаковка исходников"
sudo mkdir -p "$WORK"
sudo chown "$(id -u):$(id -g)" "$WORK"
tar -xf "/src/$KERNEL_TARBALL" -C "$WORK"
SRC=$(find "$WORK" -maxdepth 1 -mindepth 1 -type d | head -n 1)
[ -n "$SRC" ] || { echo "не нашли каталог исходников в $WORK"; exit 1; }
echo "== source=$SRC"
cd "$SRC"

echo "== версия ядра в Makefile"
grep -E '^(VERSION|PATCHLEVEL|SUBLEVEL|EXTRAVERSION)' Makefile

echo "== применяем заводской .config платформы"
cp -f "$BUILD/.config" .config
cp -f .config /tmp/config.orig

# OHCI: в конфиге Synology выключен
for opt in USB_OHCI_HCD USB_OHCI_HCD_PCI; do
  if grep -q "^CONFIG_${opt}=" .config; then
    sed -i "s/^CONFIG_${opt}=.*/CONFIG_${opt}=m/" .config
  else
    echo "CONFIG_${opt}=m" >> .config
  fi
done

# Ядро DSM собрано как 5.10.55+ (суффикс даёт setlocalversion в git у Synology),
# в тарболе git нет -> задаём суффикс явно, иначе vermagic будет 5.10.55
if grep -q '^CONFIG_LOCALVERSION=' .config; then
  sed -i 's|^CONFIG_LOCALVERSION=.*|CONFIG_LOCALVERSION="+"|' .config
else
  echo 'CONFIG_LOCALVERSION="+"' >> .config
fi
sed -i 's|^CONFIG_LOCALVERSION_AUTO=.*|# CONFIG_LOCALVERSION_AUTO is not set|' .config

# BTF для модулей 5.10 не генерируется, а tools/bpf/resolve_btfids требует python3,
# которого в образе нет -> отключаем (на ABI не влияет)
sed -i 's|^CONFIG_DEBUG_INFO_BTF=.*|# CONFIG_DEBUG_INFO_BTF is not set|' .config

echo "== olddefconfig (WERROR=0: host-gcc 12 ломает tools/lib/subcmd на -Werror)"
make -j"$(nproc)" WERROR=0 olddefconfig >/dev/null

echo "== diff .config (ожидаем только наши строки)"
diff /tmp/config.orig .config || true

echo "== Module.symvers из тулкита"
cp -f "$BUILD/Module.symvers" Module.symvers

echo "== modules_prepare"
make -j"$(nproc)" WERROR=0 modules_prepare
echo "== kernel release: $(cat include/config/kernel.release 2>/dev/null)"

echo "== сборка drivers/usb/host"
make -j"$(nproc)" WERROR=0 M=drivers/usb/host KBUILD_MODPOST_WARN=1 modules

echo "== результат"
ls -l drivers/usb/host/*.ko

for m in ohci-hcd ohci-pci ehci-pci uhci-hcd; do
  f="drivers/usb/host/$m.ko"
  [ -f "$f" ] || { echo "WARN: $f отсутствует"; continue; }
  strip -g "$f"
  cp -f "$f" /output/
done
cp -f .config /output/config.used
cp -f include/config/kernel.release /output/kernel.release

echo "== vermagic"
for f in /output/*.ko; do
  printf '%-16s %s\n' "$(basename "$f")" "$(modinfo -F vermagic "$f" 2>/dev/null)"
done
echo "== md5"
md5sum /output/*.ko
echo "== ГОТОВО"
