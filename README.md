OHCI HCD для DSM/Xpenology (epyc7002, kernel 5.10.55+)

Модули ohci-hcd.ko + ohci-pci.ko для Synology DSM 7.x на платформе epyc7002 (SA6400),
собранные под ядро 5.10.55+, которое использует ARC Loader (сборка AuxXxilium).

Linux-ядро Synology для epyc7002 не содержит драйвер OHCI (CONFIG_USB_OHCI_HCD не включён),
а на большинстве плат с чипсетами AMD SB7xx/SB8xx (HP MicroServer Gen7/N36/N40/N54, многие
материнки AM3/FM1) USB 1.1 реализован отдельными PCI-контроллерами OHCI.

EHCI обслуживает только high-speed. Любое full/low-speed устройство
(клавиатура, мышь, USB-HID ИБП) уходит на companion-контроллер OHCI. Без драйвера OHCI
такие устройства не энумерируются вообще — их не видно ни в /dev/bus/usb, ни в
/proc/bus/usb/devices, ни в DSM.

Симптомы:

$ ls /sys/bus/pci/drivers | grep -i ohci
(пусто)
$ dmesg | grep -i 'low-speed'
(пусто)


Модули привязаны к точному vermagic (5.10.55+ SMP mod_unload). Для другой платформы,
другой версии DSM или другого ядра их нужно пересобрать (см. ниже).

Установка (готовые модули)

Всё ставится на диск данных (/volume1) + один systemd-юнит. /usr/lib/modules,
depmod и загрузочная флешка не затрагиваются.

ssh
# 1. скопировать репозиторий на NAS, например в 
# 2. установить (нужен root в ssh: sudo -i): 
SRC=prebuilt/epyc7002-5.10.55+ sh install/install.sh

Скрипт
* проверяет, что vermagic модулей совпадает с uname -r (иначе откажется ставить);
* копирует ohci-hcd.ko и ohci-pci.ko в /volume1/ohci-hcd (каталог меняется через BASE=);
* создаёт /etc/systemd/system/ohci-ups.service (enabled, стартует после syno-volume.target,
  Before=ups-usb.service) — модули грузятся при каждом старте DSM;
* сразу делает insmod, чтобы ИБП заработал без перезагрузки.

Проверка и удаление:
sh
sh tools/status.sh                 # шины usb4..6, устройство, NUT, юнит
/usr/bin/upsc ups                  # battery.charge, ups.status, input.voltage...

sh install/uninstall.sh            # снять юнит и выгрузить модули
PURGE=1 sh install/uninstall.sh    # + удалить каталог с .ko



Сборка из исходников
Нужен любой хост с Docker (можно прямо на NAS: у Container Manager docker работает).

# 1. исходники ядра Synology (GPL) для своей сборки DSM
GPL_VER=7.4-90080 PLATFORM=epyc7002 sh build/fetch-gpl-source.sh
# 2. сборка в контейнере auxxxilium/syno-compiler:<DSM major.minor>
IMAGE=auxxxilium/syno-compiler:7.4 PLATFORM=epyc7002 sh build/build-ohci.sh
Результат — в out/: ohci-hcd.ko, ohci-pci.ko + контрольные ehci-pci.ko, uhci-hcd.ko.

Что делает сборка
1. Распаковывает linux-5.10.x из GPL-архива Synology.
2. Берёт  .config платформы из тулкита (/opt/<platform>/build/.config).
3. Включает CONFIG_USB_OHCI_HCD=m и CONFIG_USB_OHCI_HCD_PCI=m; ставит
   CONFIG_LOCALVERSION="+" (без него vermagic получится 5.10.55, а нужно 5.10.55+).
4. make modules_prepare + make M=drivers/usb/host modules.
5. Кладёт ehci-pci.ko/uhci-hcd.ko в out/ — они нужны для проверки ABI (см. ниже).

Особенности окружения (уже учтены в скриптах):
* WERROR=0 — иначе tools/lib/subcmd под host-gcc 12 падает на -Werror=use-after-free;
* CONFIG_DEBUG_INFO_BTF выключается, т.к. tools/bpf/resolve_btfids требует python3,
  которого в образе нет (для модулей 5.10 BTF не генерируется, на ABI не влияет).

## Структура репозитория
build/    fetch-gpl-source.sh, build-ohci.sh, in-container-build.sh
install/  install.sh, uninstall.sh, ohci-ups.service.template
tools/    status.sh, load.sh (verify/load/unload/status)
verify/   compare-abi.sh, compare-sym.sh
prebuilt/ epyc7002-5.10.55+/ (готовые .ko + MD5SUMS)
.github/  workflows/build.yml — сборка модулей в CI


Лицензия
Скрипты — MIT (LICENSE). Собранные модули — производная от ядра Linux и распространяются
под GPL-2.0 (MODULE_LICENSE("GPL")), как и исходники Synology GPL.

Благодарности
* AuxXxilium — [syno-compiler](https://github.com/AuxXxilium/syno-compiler) и ARC Loader;
* Synology — GPL-исходники ядра linux-5.10.x;
* сообщество Xpenology.