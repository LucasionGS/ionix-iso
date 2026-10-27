#!/usr/bin/env bash
# shellcheck disable=SC2034
#
# The part of the archiso profile definition both variants share. build.sh
# writes the staged profile's profiledef.sh as this file followed by the
# variant's own, which names the ISO (iso_name, iso_label, iso_application) and
# adds its scripts with `file_permissions+=( ... )`.

iso_publisher="Ionix"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="ionix"
buildmodes=('iso')
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.gnupg"]="0:0:700"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/bin/ionix-post-install"]="0:0:755"
  ["/usr/local/bin/grub-install"]="0:0:755"
)
