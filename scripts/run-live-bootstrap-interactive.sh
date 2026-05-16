#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIVE_BOOTSTRAP="$ROOT/live-bootstrap"
MIRROR="${LIVE_BOOTSTRAP_MIRROR:-https://samuelt.me/pub/live-bootstrap}"
TARGET="${LIVE_BOOTSTRAP_TARGET:-target-qemu-console}"
RAM="${LIVE_BOOTSTRAP_RAM:-4096}"
CORES="${LIVE_BOOTSTRAP_CORES:-2}"

if ! command -v qemu-system-x86_64 >/dev/null 2>&1 && [ ! -x /opt/homebrew/bin/qemu-system-x86_64 ]; then
  echo "qemu-system-x86_64 not found. Install it with: brew install qemu" >&2
  exit 1
fi

if [ ! -d "$LIVE_BOOTSTRAP/.git" ]; then
  git clone --recursive https://github.com/fosslinux/live-bootstrap.git "$LIVE_BOOTSTRAP"
else
  git -C "$LIVE_BOOTSTRAP" submodule update --init --recursive
fi

if ! git -C "$LIVE_BOOTSTRAP/builder-hex0" apply --check "$ROOT/patches/builder-hex0-macos-cut.patch" >/dev/null 2>&1; then
  if ! git -C "$LIVE_BOOTSTRAP/builder-hex0" apply --reverse --check "$ROOT/patches/builder-hex0-macos-cut.patch" >/dev/null 2>&1; then
    echo "builder-hex0 patch is neither cleanly applicable nor already applied." >&2
    exit 1
  fi
else
  git -C "$LIVE_BOOTSTRAP/builder-hex0" apply "$ROOT/patches/builder-hex0-macos-cut.patch"
fi

if [ ! -x "$LIVE_BOOTSTRAP/.venv/bin/python" ]; then
  python3 -m venv "$LIVE_BOOTSTRAP/.venv"
fi

"$LIVE_BOOTSTRAP/.venv/bin/python" -m pip install requests

cd "$LIVE_BOOTSTRAP"
PATH="$ROOT/bin:/opt/homebrew/bin:$PATH" \
  .venv/bin/python ./rootfs.py -q -i \
    -t "$TARGET" \
    -qc "$ROOT/qemu-macos-wrapper.sh" \
    -m "$MIRROR" \
    -qr "$RAM" \
    --cores "$CORES"
