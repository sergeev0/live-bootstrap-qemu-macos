# live-bootstrap stage0 in QEMU on macOS

Weekend experiment: boot the `live-bootstrap` kernel-bootstrap path from the
`stage0` / `hex0` / `builder-hex0` chain inside QEMU on macOS.

This repository contains the local glue used to run the experiment. It does not
vendor `live-bootstrap` or generated disk images.

## What works

- Homebrew QEMU 11 boots the generated x86 disk image.
- `builder-hex0-x86-stage1` loads `builder-hex0-x86-stage2`.
- The tiny `builder-hex0` kernel loads the embedded source filesystem.
- `hex0` builds `hex0-seed`, `kaem-optional-seed`, and `/init`.
- `kaem.x86` starts stage0-posix and advances into the early toolchain:
  `hex0`, `hex1`, `hex2`, `M1`, `M2`, `M2-Planet`, then Mes.

On Apple Silicon this is x86 emulation, not hardware virtualization, so the full
bootstrap may run for a long time.

## Files

- `qemu-macos-wrapper.sh` strips Linux/KVM-only QEMU flags before delegating to
  Homebrew's `qemu-system-x86_64`.
- `bin/qemu-system-x86_64` is a PATH shim for upstream scripts that call
  `qemu-system-x86_64` directly.
- `scripts/run-live-bootstrap-interactive.sh` clones/updates `live-bootstrap`,
  creates the Python virtualenv, installs `requests`, applies the macOS
  portability patch, and launches QEMU in interactive mode.
- `patches/builder-hex0-macos-cut.patch` fixes GNU/BSD `cut` argument ordering
  in `builder-hex0`'s Makefile.

## Prerequisites

```sh
brew install qemu
```

`git`, `make`, `python3`, and `xxd` are also needed. They are normally already
available on a macOS development machine.

## Run

```sh
./scripts/run-live-bootstrap-interactive.sh
```

The script uses:

```sh
https://samuelt.me/pub/live-bootstrap
```

as the live-bootstrap mirror.

The generated checkout and VM image live under:

```text
live-bootstrap/
```

That directory is intentionally ignored by git because it contains downloaded
distfiles and large sparse QEMU disk images.

## Manual command

After the script has prepared the checkout, the equivalent interactive launch is:

```sh
cd live-bootstrap
.venv/bin/python ./rootfs.py -q -i -t target-qemu-console \
  -qc ../qemu-macos-wrapper.sh \
  -m https://samuelt.me/pub/live-bootstrap \
  -qr 4096 --cores 2
```

The QEMU window shows the VM console. Early output begins with many `src` lines
while `builder-hex0` loads files into its memory filesystem. Later `+>` lines
are `kaem` executing stage0-posix commands.

## Notes

The upstream helper assumes Linux/KVM and emits flags such as `-enable-kvm` and
`-machine kernel-irqchip=split`. Those are removed by the wrapper for macOS.

The `builder-hex0` Makefile also used GNU-style `cut file -f1 -d...` ordering.
BSD `cut` treats that as invalid, so the patch changes it to portable
`cut -f1 -d... file` ordering.

