# live-bootstrap stage0 in QEMU on macOS

Weekend experiment: boot the `live-bootstrap` kernel-bootstrap path from the
`stage0` / `hex0` / `builder-hex0` chain inside QEMU on macOS.

This repository contains the local glue used to repeat the experiment. It does
not vendor `live-bootstrap` or generated disk images.

Upstream projects:

- [`fosslinux/live-bootstrap`](https://github.com/fosslinux/live-bootstrap) is
  the project doing the real bootstrap.
- [`ironmeld/builder-hex0`](https://github.com/ironmeld/builder-hex0) provides
  the tiny bootable kernel/hex0 compiler used by live-bootstrap's kernel
  bootstrap path.
- [`oriansj/stage0-posix`](https://github.com/oriansj/stage0-posix) provides
  the stage0-posix bootstrap chain.

This repo is just a macOS/QEMU wrapper and notes repo around those upstreams.

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

## Quick Start

```sh
git clone https://github.com/sergeev0/live-bootstrap-qemu-macos.git
cd live-bootstrap-qemu-macos
./scripts/run-live-bootstrap-interactive.sh
```

The script will:

- clone `https://github.com/fosslinux/live-bootstrap.git` into `./live-bootstrap`
- initialize all recursive submodules
- create `live-bootstrap/.venv`
- install Python `requests` into that virtualenv
- apply the macOS `builder-hex0` portability patch
- generate the live-bootstrap QEMU disk image
- open an interactive QEMU console window

By default it uses `https://samuelt.me/pub/live-bootstrap` as the
live-bootstrap mirror.

The generated checkout and VM image live under:

```text
live-bootstrap/
```

That directory is intentionally ignored by git because it contains downloaded
distfiles and large sparse QEMU disk images.

## What You Should See

The QEMU window starts with SeaBIOS and then prints a lot of lines like:

```text
src
./x86/hex0_x86.hex0
```

That is `builder-hex0` loading the embedded source filesystem into memory.

After that, lines like this mean stage0-posix is running:

```text
+> ./bootstrap-seeds/POSIX/x86/kaem-optional-seed ./x86/mescc-tools-seed-kaem.kaem
+> ./x86/artifact/hex0 ./x86/hex0_x86.hex0 ./x86/artifact/hex0
```

Later milestones include `M1`, `M2`, `M2-Planet`, and Mes. On Apple Silicon
this is x86 software emulation, so continuing the full bootstrap can take a
long time.

## Configuration

The launcher can be customized with environment variables:

```sh
LIVE_BOOTSTRAP_MIRROR=https://samuelt.me/pub/live-bootstrap \
LIVE_BOOTSTRAP_TARGET=target-qemu-console \
LIVE_BOOTSTRAP_RAM=4096 \
LIVE_BOOTSTRAP_CORES=2 \
./scripts/run-live-bootstrap-interactive.sh
```

By default the wrapper adds `-no-reboot`. If the guest crashes or tries to
reboot, QEMU will stop instead of silently starting the bootstrap over from the
beginning. To allow guest reboots explicitly:

```sh
LIVE_BOOTSTRAP_QEMU_ALLOW_REBOOT=1 ./scripts/run-live-bootstrap-interactive.sh
```

## Observability

Future runs can opt into QEMU inspection sockets and a serial log:

```sh
LIVE_BOOTSTRAP_QEMU_OBSERVABILITY=1 ./scripts/run-live-bootstrap-interactive.sh
```

Defaults:

```text
QEMU monitor: /tmp/live-bootstrap-qemu-monitor.sock
QMP socket:   /tmp/live-bootstrap-qemu-qmp.sock
Serial log:   /tmp/live-bootstrap-serial.log
```

Connect to the human QEMU monitor with:

```sh
nc -U /tmp/live-bootstrap-qemu-monitor.sock
```

Useful non-destructive monitor commands:

```text
info status
info cpus
info registers
```

Watch the serial log with:

```sh
tail -f /tmp/live-bootstrap-serial.log
```

The socket/log paths can be overridden:

```sh
LIVE_BOOTSTRAP_QEMU_OBSERVABILITY=1 \
LIVE_BOOTSTRAP_QEMU_MONITOR=/tmp/lb-monitor.sock \
LIVE_BOOTSTRAP_QEMU_QMP=/tmp/lb-qmp.sock \
LIVE_BOOTSTRAP_QEMU_SERIAL_LOG=/tmp/lb-serial.log \
./scripts/run-live-bootstrap-interactive.sh
```

These options must be enabled before launching the VM; they cannot be attached
to an already-running QEMU process.

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

## Re-running

Re-run the script to continue using the same local `live-bootstrap` checkout and
cached distfiles. Use a different `LIVE_BOOTSTRAP_TARGET` if you want a fresh
QEMU disk image without deleting the previous one:

```sh
LIVE_BOOTSTRAP_TARGET=target-qemu-second-run ./scripts/run-live-bootstrap-interactive.sh
```

## Notes

The upstream helper assumes Linux/KVM and emits flags such as `-enable-kvm` and
`-machine kernel-irqchip=split`. Those are removed by the wrapper for macOS.

The `builder-hex0` Makefile also used GNU-style `cut file -f1 -d...` ordering.
BSD `cut` treats that as invalid, so the patch changes it to portable
`cut -f1 -d... file` ordering.

## Attribution

Created as a weekend experiment with Codex and GPT-5.5.

## License

This wrapper/notes repo is released under the 0BSD license. See `LICENSE`.
