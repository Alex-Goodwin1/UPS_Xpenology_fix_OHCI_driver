# OHCI HCD for DSM/Xpenology (epyc7002, kernel 5.10.55+)

Русская версия: [README.md](README.md)

Modules `ohci-hcd.ko` + `ohci-pci.ko` for Synology DSM 7.x on the epyc7002 platform (SA6400),
built for the `5.10.55+` kernel used by ARC Loader (AuxXxilium build).

The Synology Linux kernel for epyc7002 does not contain the OHCI driver
(`CONFIG_USB_OHCI_HCD` is not enabled), while on most boards with AMD SB7xx/SB8xx chipsets
(HP MicroServer Gen7/N36/N40/N54, many AM3/FM1 motherboards) USB 1.1 is implemented by separate
OHCI PCI controllers.

EHCI handles high-speed only. Any full/low-speed device (keyboard, mouse, USB-HID UPS) is routed
to the OHCI companion controller. Without the OHCI driver such devices are not enumerated at all —
they are invisible in `/dev/bus/usb`, in `/proc/bus/usb/devices` and in DSM.

Symptoms:

```sh
$ ls /sys/bus/pci/drivers | grep -i ohci
(empty)
$ dmesg | grep -i 'low-speed'
(empty)
```

The modules are bound to the exact vermagic (`5.10.55+ SMP mod_unload`). For another platform,
another DSM version or another kernel they have to be rebuilt (see below).

## Installation (prebuilt modules)

Everything is installed on the data volume (`/volume1`) plus one systemd unit.
`/usr/lib/modules`, `depmod` and the boot stick are not touched.

```sh
# 1. copy the repository to the NAS, e.g. to /volume1/ohci-hcd
# 2. connect over ssh and switch to root (root rights are required for installation):
sudo -i
cd /volume1/ohci-hcd
SRC=prebuilt/epyc7002-5.10.55+ sh install/install.sh
```

The script:

* checks that the module vermagic matches `uname -r` (refuses to install otherwise);
* copies `ohci-hcd.ko` and `ohci-pci.ko` to `/volume1/ohci-hcd` (can be changed via `BASE=`);
* creates `/etc/systemd/system/ohci-ups.service` (`enabled`, starts after `syno-volume.target`,
  `Before=ups-usb.service`) — the modules are loaded on every DSM boot;
* runs `insmod` immediately so the UPS works without a reboot.

Check and removal:

```sh
sh tools/status.sh                 # buses usb4..6, device, NUT, unit
/usr/bin/upsc ups                  # battery.charge, ups.status, input.voltage...

sh install/uninstall.sh            # remove the unit and unload the modules
PURGE=1 sh install/uninstall.sh    # + delete the directory with the .ko files
```

## Building from source

Any host with Docker will do (it can be the NAS itself: Container Manager provides docker).

```sh
# 1. Synology kernel sources (GPL) for your DSM build
GPL_VER=7.4-90080 PLATFORM=epyc7002 sh build/fetch-gpl-source.sh
# 2. build inside the auxxxilium/syno-compiler:<DSM major.minor> container
IMAGE=auxxxilium/syno-compiler:7.4 PLATFORM=epyc7002 sh build/build-ohci.sh
```

Result in `out/`: `ohci-hcd.ko`, `ohci-pci.ko` plus reference `ehci-pci.ko`, `uhci-hcd.ko`.

What the build does:

1. Unpacks `linux-5.10.x` from the Synology GPL archive.
2. Takes the platform's factory `.config` from the toolkit (`/opt/<platform>/build/.config`).
3. Enables `CONFIG_USB_OHCI_HCD=m` and `CONFIG_USB_OHCI_HCD_PCI=m`; sets
   `CONFIG_LOCALVERSION="+"` (without it vermagic becomes `5.10.55` instead of `5.10.55+`).
4. `make modules_prepare` + `make M=drivers/usb/host modules`.
5. Copies `ehci-pci.ko`/`uhci-hcd.ko` to `out/` — they are needed for the ABI check (see below).

Environment quirks (already handled by the scripts):

* `WERROR=0` — otherwise `tools/lib/subcmd` fails under host-gcc 12 with `-Werror=use-after-free`;
* `CONFIG_DEBUG_INFO_BTF` is disabled because `tools/bpf/resolve_btfids` requires `python3`,
  which is not present in the image (BTF is not generated for 5.10 modules anyway, no ABI impact).

## Repository structure

```
build/    fetch-gpl-source.sh, build-ohci.sh, in-container-build.sh
install/  install.sh, uninstall.sh, ohci-ups.service.template
tools/    status.sh, load.sh (verify/load/unload/status)
verify/   compare-abi.sh, compare-sym.sh
prebuilt/ epyc7002-5.10.55+/ (prebuilt .ko + MD5SUMS)
.github/  workflows/build.yml — module build in CI
```

## License

Scripts — MIT (`LICENSE`). The built modules are a derivative of the Linux kernel and are
distributed under **GPL-2.0** (`MODULE_LICENSE("GPL")`), as are the Synology GPL sources.

## Credits

* AuxXxilium — [syno-compiler](https://github.com/AuxXxilium/syno-compiler) and ARC Loader;
* Synology — GPL kernel sources `linux-5.10.x`;
* Xpenology community.
