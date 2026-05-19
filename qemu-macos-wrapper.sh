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

if [ "${LIVE_BOOTSTRAP_QEMU_ALLOW_REBOOT:-0}" != "1" ]; then
  args+=(-no-reboot)
fi

if [ "${LIVE_BOOTSTRAP_QEMU_OBSERVABILITY:-0}" = "1" ]; then
  monitor_sock="${LIVE_BOOTSTRAP_QEMU_MONITOR:-/tmp/live-bootstrap-qemu-monitor.sock}"
  qmp_sock="${LIVE_BOOTSTRAP_QEMU_QMP:-/tmp/live-bootstrap-qemu-qmp.sock}"
  serial_log="${LIVE_BOOTSTRAP_QEMU_SERIAL_LOG:-/tmp/live-bootstrap-serial.log}"

  rm -f "$monitor_sock" "$qmp_sock"
  mkdir -p "$(dirname "$serial_log")"
  : > "$serial_log"

  args+=(
    -monitor "unix:$monitor_sock,server,nowait"
    -qmp "unix:$qmp_sock,server,nowait"
    -serial "file:$serial_log"
  )
fi

exec /opt/homebrew/bin/qemu-system-x86_64 "${args[@]}"
