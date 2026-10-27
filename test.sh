#!/bin/bash
# Boot an ISO in QEMU: the newest desktop ISO in out/, or the one given.
# A server ISO gets a test disk of its own (ionix-server-test.*), so installing
# it never overwrites the desktop test install.
#   ./test.sh [path/to.iso]

ISO="${1:-$(ls -t ./out/ionix-[0-9]*.iso 2>/dev/null | head -n1)}"
if [ ! -f "$ISO" ]; then
  echo "No ISO found. Build one, or pass its path: ./test.sh out/ionix-server-*.iso"
  exit 1
fi

PREFIX=ionix-test
case "$(basename "$ISO")" in
  ionix-server-*) PREFIX=ionix-server-test ;;
esac

# Create the test disk if it doesn't exist
if [ ! -f "$PREFIX.qcow2" ]; then
  qemu-img create -f qcow2 "$PREFIX.qcow2" 64G
fi

# Create a writable copy of OVMF_VARS for EFI variable storage (once)
if [ ! -f "$PREFIX-efivars.fd" ]; then
  cp /usr/share/edk2/x64/OVMF_VARS.4m.fd "$PREFIX-efivars.fd"
fi

# GPU acceleration needs Arch's qemu-hw-display-virtio-vga-gl package; without it
# (or for a server, which draws no desktop) plain virtio-vga does fine.
DISPLAY_ARGS=(-device virtio-vga -display gtk)
if qemu-system-x86_64 -device help 2>/dev/null | grep -q '"virtio-vga-gl"'; then
  DISPLAY_ARGS=(-device virtio-vga-gl -display gtk,gl=on)
fi

# serial= gives the disk a /dev/disk/by-id/virtio-ionix-test name, which an
# unattended server install requires.
qemu-system-x86_64 \
  -enable-kvm \
  -m 8G \
  -smp 4 \
  -cpu host \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file="$PREFIX-efivars.fd" \
  -drive if=none,id=disk0,file="$PREFIX.qcow2",format=qcow2 \
  -device virtio-blk-pci,drive=disk0,serial=ionix-test \
  -cdrom "$ISO" \
  -boot d \
  "${DISPLAY_ARGS[@]}"
