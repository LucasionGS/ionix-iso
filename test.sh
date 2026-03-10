#!/bin/bash

# Create the test disk if it doesn't exist
if [ ! -f ionix-test.qcow2 ]; then
  qemu-img create -f qcow2 ionix-test.qcow2 64G
fi

# Create a writable copy of OVMF_VARS for EFI variable storage (once)
if [ ! -f ionix-test-efivars.fd ]; then
  cp /usr/share/edk2/x64/OVMF_VARS.4m.fd ionix-test-efivars.fd
fi

qemu-system-x86_64 \
  -enable-kvm \
  -m 4G \
  -smp 4 \
  -cpu host \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file=ionix-test-efivars.fd \
  -drive file=ionix-test.qcow2,format=qcow2,if=virtio \
  -cdrom ./out/ionix-*.iso \
  -boot d \
  -device virtio-vga-gl \
  -display spice-app,gl=on