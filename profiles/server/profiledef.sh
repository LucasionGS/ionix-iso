#!/usr/bin/env bash
# shellcheck disable=SC2034
#
# Server variant. Appended to common/profiledef.sh by build.sh.

iso_name="ionix-server"
iso_label="IONIX_SRV_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_application="Ionix Server Live/Installer"
file_permissions+=(
  ["/usr/local/share/ionix/post-install.d/10-server"]="0:0:755"
  ["/usr/local/bin/ionix-server-install"]="0:0:755"
  ["/usr/local/bin/ionix-live-console"]="0:0:755"
)
