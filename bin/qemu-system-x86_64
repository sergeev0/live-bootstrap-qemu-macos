#!/usr/bin/env bash
set -euo pipefail

args=()
skip_next=0

for arg in "$@"; do
  if [ "$skip_next" -eq 1 ]; then
    skip_next=0
    continue
  fi

  case "$arg" in
    -enable-kvm)
      ;;
    -machine)
      skip_next=1
      ;;
    -machine\ kernel-irqchip=split)
      ;;
    *)
      args+=("$arg")
      ;;
  esac
done

exec /opt/homebrew/bin/qemu-system-x86_64 "${args[@]}"
