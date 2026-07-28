#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="ionix"
iso_label="IONIX_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="Ionix"
iso_application="Ionix Live/Installer DVD"
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
  ["/etc/sudoers.d/10-ionix"]="0:0:440"
  ["/root"]="0:0:750"
  ["/root/.gnupg"]="0:0:700"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/bin/ionix-post-install"]="0:0:755"
  ["/usr/local/bin/ionix-first-login"]="0:0:755"
  ["/usr/local/bin/ionix-install"]="0:0:755"
  ["/usr/local/bin/ionix-arrange-workspace"]="0:0:755"
  ["/usr/local/bin/grub-install"]="0:0:755"
  ["/usr/local/bin/ionix-session-selector"]="0:0:755"
  ["/etc/grub.d/11_ionix_gnome"]="0:0:755"
  ["/etc/grub.d/12_ionix_kde"]="0:0:755"
  ["/home/liveuser"]="1000:1000:750"
  ["/etc/skel/.config/hypr/scripts/alttab/alttab.sh"]="0:0:755"
  ["/etc/skel/.config/hypr/scripts/alttab/preview.sh"]="0:0:755"
  ["/etc/skel/.config/hypr/scripts/alttab/enable.sh"]="0:0:755"
  ["/etc/skel/.config/hypr/scripts/alttab/disable.sh"]="0:0:755"
  ["/etc/skel/.config/ionix/scripts/promptwallpaper.sh"]="0:0:755"
  ["/etc/skel/.config/ionix/scripts/ionix-settheme.sh"]="0:0:755"
  ["/etc/skel/.config/ionix/cron/cycle-wallpaper.sh"]="0:0:755"
)
