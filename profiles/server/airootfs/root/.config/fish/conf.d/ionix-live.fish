# Live medium only (the installer removes it). kmscon owns the screen, so kernel
# console output does not show there: what ionix-live-setup said at boot (the
# answer file it found, the SSH keys, an install it skipped) is repeated here,
# and an unattended install's progress is followed. Ctrl+C gives a shell; the
# install carries on. -t keeps it to the installer's own lines, not what
# useradd or runuser log from the chroot.
status is-login; or return

if test "$(systemctl show -P LoadState ionix-autoinstall 2>/dev/null)" = loaded
    echo "Unattended install running. Ctrl+C for a shell; the install carries on."
    journalctl -f -n all -o cat -t ionix-server-install
else
    journalctl -b -o cat -t ionix-server-install 2>/dev/null
end
