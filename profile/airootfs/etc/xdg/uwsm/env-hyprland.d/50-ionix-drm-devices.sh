# Sourced (POSIX sh) by uwsm before Hyprland starts. Points Aquamarine at the
# real GPU instead of the firmware framebuffer it otherwise grabs while the GPU
# driver is still loading — see /usr/local/bin/ionix-drm-devices.
# Set AQ_DRM_DEVICES in ~/.config/uwsm/env-hyprland to choose by hand: that file
# is sourced after this one.
if [ -z "${AQ_DRM_DEVICES:-}" ] && [ -x /usr/local/bin/ionix-drm-devices ]; then
  __ionix_drm__="$(/usr/local/bin/ionix-drm-devices)" && export AQ_DRM_DEVICES="${__ionix_drm__}"
  unset __ionix_drm__
fi
