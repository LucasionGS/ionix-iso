#!/usr/bin/env bash
# Ionix USB Writer
# Clones a built Ionix ISO onto a USB stick with dd, so it can be booted and
# installed on real hardware.
#
# Usage: ./flash-usb.sh [ISO] [--device /dev/sdX] [--verify] [--list] [--yes]
#
#   ISO         Path to the image. Defaults to the newest out/ionix-*.iso
#   --device    Skip the interactive picker and target this disk
#   --verify    Read the stick back afterwards and compare checksums
#   --list      Print the detected disks and exit
#   --yes       Skip the typed confirmation (for unattended use ONLY)
#
# This overwrites the target disk completely. The system disk is never offered
# and cannot be selected.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# presentation
# ---------------------------------------------------------------------------
if [[ -t 1 ]] && [[ "${TERM:-dumb}" != "dumb" ]]; then
    B=$'\e[1m'; DIM=$'\e[2m'; R=$'\e[0m'
    ACCENT=$'\e[38;5;141m'   # Ionix violet
    GREEN=$'\e[38;5;41m'; YELLOW=$'\e[38;5;214m'; RED=$'\e[38;5;203m'
    HIDE_CUR=$'\e[?25l'; SHOW_CUR=$'\e[?25h'
else
    B=""; DIM=""; R=""; ACCENT=""; GREEN=""; YELLOW=""; RED=""
    HIDE_CUR=""; SHOW_CUR=""
fi

die()  { printf '%s\n' "${RED}error:${R} $*" >&2; exit 1; }
warn() { printf '%s\n' "${YELLOW}warning:${R} $*" >&2; }
info() { printf '%s\n' "${ACCENT}==>${R} $*"; }

# Bytes -> human units. Integer math only, so no locale/`bc` surprises.
human() {
    local bytes=$1
    if   (( bytes >= 1073741824 )); then printf '%d.%02d GiB' $((bytes/1073741824)) $(( (bytes%1073741824)*100/1073741824 ))
    elif (( bytes >= 1048576 ));    then printf '%d.%02d MiB' $((bytes/1048576))    $(( (bytes%1048576)*100/1048576 ))
    elif (( bytes >= 1024 ));       then printf '%d.%02d KiB' $((bytes/1024))       $(( (bytes%1024)*100/1024 ))
    else printf '%d B' "$bytes"; fi
}

hms() { printf '%d:%02d:%02d' $(( $1/3600 )) $(( ($1%3600)/60 )) $(( $1%60 )); }

# Milliseconds since the epoch. `date +%s%3N` rather than $EPOCHREALTIME because
# the latter formats with the locale's decimal separator -- a comma under da_DK,
# which breaks arithmetic.
now_ms() { date +%s%3N; }

# ---------------------------------------------------------------------------
# arguments
# ---------------------------------------------------------------------------
ISO=""; DEV=""; VERIFY=false; LIST_ONLY=false; ASSUME_YES=false

while (( $# )); do
    case "$1" in
        --device) DEV="${2:-}"; [[ -n "$DEV" ]] || die "--device needs an argument"; shift 2 ;;
        --device=*) DEV="${1#*=}"; shift ;;
        --verify) VERIFY=true; shift ;;
        --list)   LIST_ONLY=true; shift ;;
        --yes|-y) ASSUME_YES=true; shift ;;
        -h|--help) sed -n '2,15p' "$0" | sed 's/^# \?//'; exit 0 ;;
        -*) die "unknown option: $1" ;;
        *)  [[ -z "$ISO" ]] || die "unexpected argument: $1"; ISO="$1"; shift ;;
    esac
done

# ---------------------------------------------------------------------------
# disk discovery
#
# The system disk is identified by walking up from whatever backs / -- on this
# distro that is an ext4 partition, so PKNAME gives the parent disk. Anything
# resolving to that disk is shown but permanently locked out; a mistake here
# destroys the running machine, and no amount of confirmation text makes that
# recoverable.
# ---------------------------------------------------------------------------
root_src="$(findmnt -no SOURCE / 2>/dev/null || true)"
SYSTEM_DISK=""
if [[ -n "$root_src" && -b "$root_src" ]]; then
    SYSTEM_DISK="$(lsblk -no PKNAME "$root_src" 2>/dev/null | head -1 | tr -d ' ')"
    [[ -n "$SYSTEM_DISK" ]] || SYSTEM_DISK="$(basename "$root_src")"
fi

declare -a D_PATH D_SIZE D_TRAN D_MODEL D_HOT D_SYS

# Model strings contain spaces and occasionally quotes, so each field is queried
# on its own rather than split out of one combined line.
field() { lsblk -dno "$2" "$1" 2>/dev/null | head -1 | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//'; }

scan_disks() {
    D_PATH=(); D_SIZE=(); D_TRAN=(); D_MODEL=(); D_HOT=(); D_SYS=()
    local name type model
    while read -r name type; do
        [[ "$type" == "disk" ]] || continue
        # zram/loop/device-mapper/optical are never flash targets
        case "$name" in /dev/zram*|/dev/loop*|/dev/dm-*|/dev/sr*) continue ;; esac
        model="$(field "$name" MODEL)"
        D_PATH+=("$name")
        D_SIZE+=("$(field "$name" SIZE)")
        D_TRAN+=("$(field "$name" TRAN)")
        D_HOT+=("$(field "$name" HOTPLUG)")
        D_MODEL+=("${model:-unknown}")
        if [[ -n "$SYSTEM_DISK" && "$(basename "$name")" == "$SYSTEM_DISK" ]]; then
            D_SYS+=(yes)
        else
            D_SYS+=(no)
        fi
    done < <(lsblk -dpno NAME,TYPE 2>/dev/null)
}

print_disks() {
    printf '\n%s\n' "${B}Available disks${R}"
    printf '%s\n' "${DIM}  #   device            size      bus     removable  model${R}"
    local i
    for i in "${!D_PATH[@]}"; do
        local flag="" hot="no" idx
        [[ "${D_HOT[$i]}" == "1" ]] && hot="yes"
        local tran="${D_TRAN[$i]:-?}"
        idx="$((i+1))"
        if [[ "${D_SYS[$i]}" == "yes" ]]; then
            flag="  ${RED}<- system disk, locked${R}"
            printf '%s\n' "${DIM}  --  $(printf '%-16s %-9s %-7s %-10s %s' \
                "${D_PATH[$i]}" "${D_SIZE[$i]}" "$tran" "$hot" "${D_MODEL[$i]}")${R}${flag}"
        else
            [[ "$hot" == "yes" ]] && flag="  ${GREEN}<- removable${R}"
            printf '  %s%2s%s  %s\n' "${ACCENT}${B}" "$idx" "${R}" \
                "$(printf '%-16s %-9s %-7s %-10s %s' \
                   "${D_PATH[$i]}" "${D_SIZE[$i]}" "$tran" "$hot" "${D_MODEL[$i]}")${flag}"
        fi
    done
    printf '\n'
}

# Partition table of one disk, so the user can recognise their own stick.
print_partitions() {
    local dev="$1" out
    out="$(lsblk -no NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "$dev" 2>/dev/null | tail -n +2)"
    if [[ -n "${out//[[:space:]]/}" ]]; then
        printf '%s\n' "${DIM}  existing contents:${R}"
        printf '%s\n' "$out" | sed 's/^/    /'
    else
        printf '%s\n' "${DIM}  existing contents: no partitions${R}"
    fi
}

scan_disks
(( ${#D_PATH[@]} )) || die "no block devices found"

if $LIST_ONLY; then
    print_disks
    exit 0
fi

# ---------------------------------------------------------------------------
# locate the ISO
# ---------------------------------------------------------------------------
if [[ -z "$ISO" ]]; then
    # newest first; out/ is root-owned after a docker build, hence the sudo probe
    mapfile -t candidates < <(ls -1t "$SCRIPT_DIR"/out/ionix-*.iso 2>/dev/null || true)
    if (( ${#candidates[@]} == 0 )) && sudo -n true 2>/dev/null; then
        mapfile -t candidates < <(sudo ls -1t "$SCRIPT_DIR"/out/ionix-*.iso 2>/dev/null || true)
    fi
    (( ${#candidates[@]} )) || die "no ISO found in out/ -- build one first, or pass a path"
    ISO="${candidates[0]}"
fi

[[ -f "$ISO" ]] || die "not a file: $ISO"
[[ -r "$ISO" ]] || die "cannot read $ISO (try: sudo chown \$USER $ISO)"
ISO_SIZE="$(stat -c %s "$ISO")"
(( ISO_SIZE > 0 )) || die "$ISO is empty"

# ---------------------------------------------------------------------------
# pick the target
# ---------------------------------------------------------------------------
if [[ -z "$DEV" ]]; then
    print_disks
    read -rp "Select a disk by number (or q to quit): " choice
    [[ "$choice" =~ ^[Qq]$ ]] && { echo "Aborted."; exit 0; }
    [[ "$choice" =~ ^[0-9]+$ ]] || die "not a number: $choice"
    idx=$((choice-1))
    (( idx >= 0 && idx < ${#D_PATH[@]} )) || die "no such entry: $choice"
    [[ "${D_SYS[$idx]}" == "no" ]] || die "that is the system disk; refusing"
    DEV="${D_PATH[$idx]}"
else
    [[ -b "$DEV" ]] || die "not a block device: $DEV"
fi

# Re-check the choice against the system disk, since --device bypasses the menu.
if [[ -n "$SYSTEM_DISK" && "$(basename "$DEV")" == "$SYSTEM_DISK" ]]; then
    die "$DEV is the system disk; refusing"
fi
# Reject partitions -- a bootable image has to own the whole device.
if [[ "$(lsblk -dno TYPE "$DEV" 2>/dev/null)" != "disk" ]]; then
    die "$DEV is not a whole disk (pass /dev/sdX, not /dev/sdX1)"
fi

DEV_SIZE="$(blockdev --getsize64 "$DEV" 2>/dev/null || sudo blockdev --getsize64 "$DEV")"
(( DEV_SIZE >= ISO_SIZE )) || die "$DEV holds $(human "$DEV_SIZE"), image needs $(human "$ISO_SIZE")"

# ---------------------------------------------------------------------------
# confirm
# ---------------------------------------------------------------------------
dev_model=""; dev_hot="no"
for i in "${!D_PATH[@]}"; do
    if [[ "${D_PATH[$i]}" == "$DEV" ]]; then
        dev_model="${D_MODEL[$i]}"
        [[ "${D_HOT[$i]}" == "1" ]] && dev_hot="yes"
    fi
done

printf '\n%s\n' "${B}About to write${R}"
printf "  %-9s %s  ${DIM}(%s)${R}\n" "image"  "$(basename "$ISO")" "$(human "$ISO_SIZE")"
printf "  %-9s %s  ${DIM}(%s, %s, removable: %s)${R}\n" \
    "target" "$DEV" "$(human "$DEV_SIZE")" "${dev_model:-unknown}" "$dev_hot"
print_partitions "$DEV"

if [[ "$dev_hot" != "yes" ]]; then
    printf '\n%s\n' "${YELLOW}This disk is not marked removable. Double-check it is really your USB stick.${R}"
fi

printf '\n%s\n' "${RED}${B}Everything on $DEV will be destroyed.${R}"

if ! $ASSUME_YES; then
    printf '%s' "Type the device path (${B}$DEV${R}) to continue: "
    read -r typed
    [[ "$typed" == "$DEV" ]] || { echo "Aborted."; exit 1; }
fi

# ---------------------------------------------------------------------------
# write
# ---------------------------------------------------------------------------
# Get any password prompt out of the way here rather than in the middle of the
# progress bar. The probe is `sudo -n true`, not `sudo -v`: `-v` validates the
# user's password, which a NOPASSWD sudoers rule does not satisfy, so it fails
# (and, without -n, blocks on a prompt) on exactly the machines where sudo works
# fine.
if sudo -n true 2>/dev/null; then
    :
elif [[ -t 0 ]]; then
    sudo -v || die "sudo is required to write to $DEV"
else
    die "sudo is required to write to $DEV, and there is no terminal to prompt on"
fi

# Any mounted partition of the target has to go, or the kernel keeps writing
# stale cached blocks over the freshly written image.
while read -r part mnt; do
    [[ -n "$mnt" ]] || continue
    info "Unmounting $part ($mnt)"
    sudo umount "$part" || die "could not unmount $part"
done < <(lsblk -lno PATH,MOUNTPOINT "$DEV" | tail -n +2)

term_width() { local c; c=$(tput cols 2>/dev/null || echo 80); (( c > 40 )) || c=80; printf '%d' "$c"; }

draw_progress() {
    local done_b=$1 total=$2 elapsed_ms=$3 width bar_w filled pct rate eta
    width=$(term_width)
    pct=$(( total > 0 ? done_b * 100 / total : 0 ))
    (( pct > 100 )) && pct=100

    # bar gets whatever is left after the fixed-width stats tail
    bar_w=$(( width - 46 )); (( bar_w < 10 )) && bar_w=10; (( bar_w > 60 )) && bar_w=60
    filled=$(( pct * bar_w / 100 ))

    local bar=""
    (( filled > 0 ))            && bar+=$(printf '█%.0s' $(seq 1 $filled))
    (( bar_w - filled > 0 ))    && bar+=$(printf '░%.0s' $(seq 1 $((bar_w-filled))))

    rate=0; (( elapsed_ms > 0 )) && rate=$(( done_b * 1000 / elapsed_ms ))
    eta="--:--:--"
    if (( rate > 0 )); then
        if (( total > done_b )); then eta="$(hms $(( (total-done_b) / rate )))"; else eta="0:00:00"; fi
    fi

    printf '\r\e[2K  %s%s%s %3d%%  %s / %s  %s/s  eta %s' \
        "$ACCENT" "$bar" "$R" "$pct" \
        "$(human "$done_b")" "$(human "$total")" "$(human "$rate")" "$eta"
}

printf '\n%s\n\n' "${ACCENT}==>${R} Writing $(basename "$ISO") to $DEV"
printf '%s' "$HIDE_CUR"
trap 'printf '\''%s'\'' "$SHOW_CUR"' EXIT INT TERM

start_ms=$(now_ms)

# oflag=direct bypasses the page cache so the byte counter reflects bytes that
# actually reached the stick. Without it dd races to "100%" in seconds and then
# blocks in fsync with no output at all, which reads as a hang on slow media.
# ISO sizes are multiples of the 2048-byte ISO9660 sector, so the final block
# stays aligned and direct I/O accepts it.
set +e
LC_ALL=C sudo dd if="$ISO" of="$DEV" bs=4M iflag=fullblock oflag=direct \
    conv=fsync status=progress 2>&1 |
while IFS= read -r -d $'\r' line || [[ -n "$line" ]]; do
    # every progress line starts with a plain integer byte count
    [[ "$line" =~ ^([0-9]+)\ bytes ]] || continue
    draw_progress "${BASH_REMATCH[1]}" "$ISO_SIZE" "$(( $(now_ms) - start_ms ))"
done
dd_status=${PIPESTATUS[0]}
set -e

(( dd_status == 0 )) || { printf '\n'; die "dd failed with status $dd_status"; }

draw_progress "$ISO_SIZE" "$ISO_SIZE" "$(( $(now_ms) - start_ms ))"
printf '\n\n'

info "Flushing buffers..."
sync
sudo blockdev --flushbufs "$DEV" 2>/dev/null || true

elapsed=$(( ($(now_ms) - start_ms) / 1000 ))
printf '%s\n' "${GREEN}==>${R} Wrote $(human "$ISO_SIZE") in $(hms "$elapsed")"

# ---------------------------------------------------------------------------
# verify
# ---------------------------------------------------------------------------
if $VERIFY; then
    info "Verifying (reading $(human "$ISO_SIZE") back from $DEV)..."
    iso_sum="$(sha256sum "$ISO" | cut -d' ' -f1)"
    dev_sum="$(sudo dd if="$DEV" bs=4M iflag=fullblock count=$(( (ISO_SIZE + 4194303) / 4194304 )) \
                 status=none 2>/dev/null | head -c "$ISO_SIZE" | sha256sum | cut -d' ' -f1)"
    if [[ "$iso_sum" == "$dev_sum" ]]; then
        printf '%s\n' "${GREEN}==>${R} Verified: checksums match"
    else
        printf '%s\n' "${RED}==>${R} MISMATCH -- the stick does not match the image"
        printf '    image: %s\n    stick: %s\n' "$iso_sum" "$dev_sum"
        exit 1
    fi
fi

printf '\n%s\n' "${B}Done.${R} $DEV is now bootable. Eject it with:"
printf '  %s\n\n' "${DIM}udisksctl power-off -b $DEV${R}"
