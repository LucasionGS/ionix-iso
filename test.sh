#!/bin/bash
qemu-system-x86_64 \
  -enable-kvm \
  -m 4G \
  -smp 4 \
  -cpu host \
  -drive file=ionix-test.qcow2,format=qcow2,if=virtio \
  -cdrom ./out/ionix-*.iso \
  -boot d \
  -device virtio-vga-gl \
  -display spice-app,gl=on