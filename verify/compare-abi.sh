#!/bin/bash
# SPDX-License-Identifier: MIT
# Сравнение КОДА наших модулей с системными (/ref) — косвенная проверка ABI.
# Запускать в контейнере с binutils, например:
#   docker run --rm -v "$PWD/verify:/kit:ro" -v <ref>:/ref:ro -v <out>:/out:ro \
#     auxxxilium/syno-compiler:7.4 bash /kit/compare-abi.sh
# Критерий: ehci-pci.ko должен совпасть с системным (допустимы отличия в имени файла
# и нумерации __UNIQUE_ID_*). Тогда смещения полей структур совпадают -> ABI ок.
RC=0
for m in ehci-pci uhci-hcd; do
  [ -f "/ref/$m.ko" ] || { echo "нет /ref/$m.ko — пропуск"; continue; }
  [ -f "/out/$m.ko" ] || { echo "нет /out/$m.ko — пропуск"; continue; }
  echo "=== $m"
  for src in ref out; do
    objdump -d --no-show-raw-insn "/$src/$m.ko" 2>/dev/null \
      | sed -E 's/^ *[0-9a-f]+:\s*//' > "/tmp/$src.txt"
  done
  # отбрасываем строку с путём к файлу
  sed -i '/file format elf/d' /tmp/ref.txt /tmp/out.txt
  d=$(diff /tmp/ref.txt /tmp/out.txt | grep -c '^[<>]')
  echo "строк: ref=$(wc -l < /tmp/ref.txt) out=$(wc -l < /tmp/out.txt), отличий: $d"
  if [ "$d" != "0" ]; then
    echo "--- отличия (первые 30):"
    diff -u /tmp/ref.txt /tmp/out.txt | sed -n '1,30p'
    [ "$m" = "ehci-pci" ] && RC=1
  fi
done
echo "=== размеры .text"
for src in ref out; do
  printf '%-4s' "$src"
  for m in ehci-pci uhci-hcd; do
    [ -f "/$src/$m.ko" ] && printf ' %s=%s' "$m" "$(objdump -h "/$src/$m.ko" 2>/dev/null | awk '/\.text /{print $3}')"
  done
  echo
done
echo "=== ИТОГ: $([ $RC = 0 ] && echo 'ABI OK (ehci-pci совпал)' || echo 'ВНИМАНИЕ: ehci-pci отличается, модули грузить рискованно')"
exit $RC
