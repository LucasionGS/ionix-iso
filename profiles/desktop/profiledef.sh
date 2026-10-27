#!/usr/bin/env bash
# shellcheck disable=SC2034
#
# Desktop variant. Appended to common/profiledef.sh by build.sh.

iso_name="ionix"
iso_label="IONIX_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_application="Ionix Live/Installer DVD"
file_permissions+=(
  ["/etc/sudoers.d/10-ionix"]="0:0:440"
  ["/usr/local/share/ionix/post-install.d/10-desktop"]="0:0:755"
  ["/usr/local/bin/ionix-first-login"]="0:0:755"
  ["/usr/local/bin/ionix-extras"]="0:0:755"
  ["/usr/local/bin/ionix-install"]="0:0:755"
  ["/usr/local/bin/ionix-arrange-workspace"]="0:0:755"
  ["/usr/local/bin/ionix-project"]="0:0:755"
  ["/usr/local/bin/ionix-fingerprint"]="0:0:755"
  ["/usr/local/bin/ionix-login-mode"]="0:0:755"
  ["/home/liveuser"]="1000:1000:750"
  ["/usr/local/share/ionix/bin/ionix-wallpaper"]="0:0:755"
  ["/usr/local/share/ionix/bin/ionix-cycle-wallpaper"]="0:0:755"
  ["/usr/local/share/ionix/bin/ionix-adaptive-colors"]="0:0:755"
)
