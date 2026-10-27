#!/bin/bash
# SPDX-License-Identifier: MIT
# Сравнение списка функций нашей сборки и системных модулей.
#   docker run --rm -v "$PWD/verify:/kit:ro" -v <ref>:/ref:ro -v <out>:/out:ro \
#     auxxxilium/syno-compiler:7.4 bash /kit/compare-sym.sh
for m in ehci-pci uhci-hcd; do
  [ -f "/ref/$m.ko" ] || continue
  echo "=== $m"
  objdump -t "/ref/$m.ko" | awk '$2 ~ /^[TtWw]$/ {print $NF}' | sort -u > /tmp/ref.sym
  objdump -t "/out/$m.ko" | awk '$2 ~ /^[TtWw]$/ {print $NF}' | sort -u > /tmp/out.sym
  echo "функций: ref=$(wc -l < /tmp/ref.sym) out=$(wc -l < /tmp/out.sym)"
  echo "--- только в системном:"; comm -23 /tmp/ref.sym /tmp/out.sym | head -20
  echo "--- только в нашей сборке:"; comm -13 /tmp/ref.sym /tmp/out.sym | head -20
done
