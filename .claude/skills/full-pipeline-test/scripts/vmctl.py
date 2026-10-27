#!/usr/bin/env python3
"""Headless QEMU driver for Ionix ISO install/boot testing.

Runs a VM with no display, and drives it entirely over QMP: keystrokes, mouse
clicks and PNG screenshots. Every subcommand is a separate short-lived process
that reconnects to the VM's QMP socket, so an agent can drive the VM one shell
call at a time.

Coordinates are in framebuffer pixels, taken straight off the screenshots;
they are converted to QEMU's 0..32767 absolute range using the live
framebuffer size, so they stay correct across resolution changes.
"""

import argparse
import json
import os
import shutil
import signal
import socket
import struct
import subprocess
import sys
import time

RUNDIR = os.environ.get("IONIX_VM_RUNDIR", "/tmp/ionix-vm")
QMP_SOCK = os.path.join(RUNDIR, "qmp.sock")
PIDFILE = os.path.join(RUNDIR, "qemu.pid")
LOGFILE = os.path.join(RUNDIR, "qemu.log")
SERIALLOG = os.path.join(RUNDIR, "serial.log")
LASTSHOT = os.path.join(RUNDIR, "_dims.png")

OVMF_CODE = "/usr/share/edk2/x64/OVMF_CODE.4m.fd"
OVMF_VARS = "/usr/share/edk2/x64/OVMF_VARS.4m.fd"

ABS_MAX = 32767


# --------------------------------------------------------------------------
# QMP
# --------------------------------------------------------------------------
class Qmp:
    def __init__(self, path=QMP_SOCK, timeout=30):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.settimeout(timeout)
        self.sock.connect(path)
        self.buf = b""
        self._read_json()  # greeting
        self.cmd("qmp_capabilities")

    def _read_json(self):
        while True:
            nl = self.buf.find(b"\n")
            if nl >= 0:
                line, self.buf = self.buf[:nl], self.buf[nl + 1:]
                if line.strip():
                    return json.loads(line)
                continue
            chunk = self.sock.recv(65536)
            if not chunk:
                raise RuntimeError("QMP connection closed")
            self.buf += chunk

    def cmd(self, execute, **args):
        msg = {"execute": execute}
        if args:
            msg["arguments"] = args
        self.sock.sendall((json.dumps(msg) + "\n").encode())
        while True:
            reply = self._read_json()
            if "event" in reply:
                continue  # ignore async events
            if "error" in reply:
                raise RuntimeError(f"{execute}: {reply['error']['desc']}")
            return reply.get("return")

    def close(self):
        try:
            self.sock.close()
        except OSError:
            pass


# --------------------------------------------------------------------------
# keymap
# --------------------------------------------------------------------------
# QEMU qcodes are US-layout scancode names. The guest applies its own layout on
# top, so alphanumerics are safe on any layout but punctuation is NOT -- see the
# skill doc.
PLAIN = {
    " ": "spc", "\n": "ret", "\t": "tab",
    "-": "minus", "=": "equal", "[": "bracket_left", "]": "bracket_right",
    "\\": "backslash", ";": "semicolon", "'": "apostrophe", "`": "grave_accent",
    ",": "comma", ".": "dot", "/": "slash",
}
SHIFTED = {
    "!": "1", "@": "2", "#": "3", "$": "4", "%": "5", "^": "6", "&": "7",
    "*": "8", "(": "9", ")": "0", "_": "minus", "+": "equal",
    "{": "bracket_left", "}": "bracket_right", "|": "backslash",
    ":": "semicolon", '"': "apostrophe", "~": "grave_accent",
    "<": "comma", ">": "dot", "?": "slash",
}
# Aliases so callers can use familiar names.
KEY_ALIASES = {
    "enter": "ret", "return": "ret", "space": "spc", "esc": "esc",
    "escape": "esc", "backspace": "backspace", "del": "delete",
    "super": "meta_l", "win": "meta_l", "meta": "meta_l",
    "pgup": "pgup", "pgdn": "pgdn", "pageup": "pgup", "pagedown": "pgdn",
    "up": "up", "down": "down", "left": "left", "right": "right",
}


def char_to_keys(ch):
    """Return the qcode list for one character."""
    if ch in PLAIN:
        return [PLAIN[ch]]
    if ch in SHIFTED:
        return ["shift", SHIFTED[ch]]
    if ch.isupper():
        return ["shift", ch.lower()]
    if ch.isalnum():
        return [ch]
    raise ValueError(f"no qcode mapping for {ch!r}")


def parse_combo(spec):
    """'ctrl-alt-f2' -> ['ctrl', 'alt', 'f2']"""
    parts = spec.split("-") if spec != "-" else ["minus"]
    return [KEY_ALIASES.get(p.lower(), p.lower()) for p in parts]


def send_keys(qmp, qcodes, hold=80):
    qmp.cmd("send-key",
            keys=[{"type": "qcode", "data": k} for k in qcodes],
            **{"hold-time": hold})


# --------------------------------------------------------------------------
# framebuffer
# --------------------------------------------------------------------------
def screendump(qmp, path):
    path = os.path.abspath(path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    qmp.cmd("screendump", filename=path, format="png")
    # screendump is asynchronous in the sense that the file is written by the
    # time the command returns, but a zero-byte file means the guest has no
    # active display surface yet.
    for _ in range(50):
        if os.path.exists(path) and os.path.getsize(path) > 0:
            return path
        time.sleep(0.1)
    return path


def png_dims(path):
    with open(path, "rb") as fh:
        head = fh.read(24)
    if len(head) < 24 or head[:8] != b"\x89PNG\r\n\x1a\n":
        raise RuntimeError(f"{path} is not a PNG (guest display not up yet?)")
    return struct.unpack(">II", head[16:24])


def current_dims(qmp):
    screendump(qmp, LASTSHOT)
    return png_dims(LASTSHOT)


def move_mouse(qmp, x, y, dims):
    w, h = dims
    ax = max(0, min(ABS_MAX, round(x * ABS_MAX / max(1, w - 1))))
    ay = max(0, min(ABS_MAX, round(y * ABS_MAX / max(1, h - 1))))
    qmp.cmd("input-send-event", events=[
        {"type": "abs", "data": {"axis": "x", "value": ax}},
        {"type": "abs", "data": {"axis": "y", "value": ay}},
    ])


# --------------------------------------------------------------------------
# lifecycle
# --------------------------------------------------------------------------
def vm_pid():
    try:
        with open(PIDFILE) as fh:
            pid = int(fh.read().strip())
    except (OSError, ValueError):
        return None
    try:
        os.kill(pid, 0)
    except OSError:
        return None
    return pid


def do_start(args):
    if vm_pid():
        sys.exit("a VM is already running; run `vmctl.py quit` first")

    # AF_UNIX paths are capped at ~108 bytes by the kernel, and QEMU refuses
    # anything longer. A deep IONIX_VM_RUNDIR is the usual cause.
    if len(QMP_SOCK.encode()) > 100:
        sys.exit(f"QMP socket path is too long ({len(QMP_SOCK)} bytes, max 100):"
                 f"\n  {QMP_SOCK}\nSet IONIX_VM_RUNDIR to something shorter.")

    os.makedirs(RUNDIR, exist_ok=True)
    for stale in (QMP_SOCK, PIDFILE):
        if os.path.exists(stale):
            os.unlink(stale)

    disk = os.path.abspath(args.disk)
    efivars = os.path.abspath(args.efivars)

    if args.fresh_disk and os.path.exists(disk):
        os.unlink(disk)
    if not os.path.exists(disk):
        subprocess.run(["qemu-img", "create", "-f", "qcow2", disk, args.size],
                       check=True, stdout=subprocess.DEVNULL)
    if args.fresh_disk and os.path.exists(efivars):
        os.unlink(efivars)
    if not os.path.exists(efivars):
        shutil.copy(OVMF_VARS, efivars)

    cmd = [
        "qemu-system-x86_64",
        "-enable-kvm", "-m", args.memory, "-smp", args.cpus, "-cpu", "host",
        "-machine", "q35",
        "-drive", f"if=pflash,format=raw,readonly=on,file={OVMF_CODE}",
        "-drive", f"if=pflash,format=raw,file={efivars}",
        "-drive", f"file={disk},format=qcow2,if=virtio",
    ]
    # virtio-vga-gl + egl-headless puts the scanout on a dmabuf as soon as the
    # guest's virtio-gpu driver takes over, and QMP screendump cannot read that
    # back -- every capture fails with "no surface". Plain 2D virtio-vga keeps a
    # host-side surface alive for the whole boot, at the cost of software GL in
    # the guest. Screenshots are the entire point here, so 2D is the default.
    if args.gl:
        cmd += [
            "-device", f"virtio-vga-gl,xres={args.width},yres={args.height}",
            "-display", f"egl-headless,rendernode={args.rendernode}",
        ]
    else:
        # --headed opens a GTK window on the host so a person can watch (or take
        # over); screendump and QMP input keep working exactly as headless.
        # A display cannot be attached to a running QEMU, so decide at start.
        cmd += [
            "-device", f"virtio-vga,xres={args.width},yres={args.height}",
            "-display", "gtk,zoom-to-fit=on" if args.headed else "none",
        ]
    cmd += [
        "-device", "virtio-tablet-pci",   # absolute pointer: clicks land where told
        "-device", "virtio-keyboard-pci",
        "-netdev", "user,id=net0" + "".join(f",hostfwd=tcp:127.0.0.1:{f.replace(':', '-:')}" for f in args.forward),
        "-device", "virtio-net-pci,netdev=net0",
        "-qmp", f"unix:{QMP_SOCK},server=on,wait=off",
        "-pidfile", PIDFILE,
        # Kernel console to a file: the only way to see why a boot died once the
        # graphical handoff has already blanked the framebuffer.
        "-serial", f"file:{SERIALLOG}",
        "-name", "ionix-test",
    ]
    if args.iso:
        cmd += ["-drive", f"file={os.path.abspath(args.iso)},media=cdrom,readonly=on",
                "-boot", "menu=off,order=dc"]
    else:
        cmd += ["-boot", "order=c"]

    log = open(LOGFILE, "wb")
    subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT,
                     stdin=subprocess.DEVNULL, start_new_session=True)

    for _ in range(100):
        if os.path.exists(QMP_SOCK):
            try:
                Qmp().close()
                print(f"started (pid {vm_pid()}), qmp={QMP_SOCK}, log={LOGFILE}")
                return
            except (OSError, RuntimeError):
                pass
        if vm_pid() is None and os.path.getsize(LOGFILE) > 0:
            break
        time.sleep(0.2)
    with open(LOGFILE) as fh:
        sys.exit("qemu failed to start:\n" + fh.read()[-2000:])


def do_quit(args):
    pid = vm_pid()
    if not pid:
        print("no VM running")
        return
    try:
        Qmp(timeout=5).cmd("quit")
    except (OSError, RuntimeError):
        os.kill(pid, signal.SIGTERM)
    for _ in range(50):
        if vm_pid() is None:
            print("stopped")
            return
        time.sleep(0.2)
    os.kill(pid, signal.SIGKILL)
    print("killed")


def do_powerdown(args):
    Qmp().cmd("system_powerdown")
    print("ACPI powerdown sent")


def do_waitoff(args):
    deadline = time.time() + args.timeout
    while time.time() < deadline:
        if vm_pid() is None:
            print("vm is off")
            return
        time.sleep(2)
    sys.exit(f"VM still running after {args.timeout}s")


def do_status(args):
    pid = vm_pid()
    if not pid:
        print("stopped")
        return
    try:
        qmp = Qmp(timeout=5)
        st = qmp.cmd("query-status")
        try:
            dims = current_dims(qmp)
            dim_s = f", display {dims[0]}x{dims[1]}"
        except Exception as exc:
            dim_s = f", display unavailable ({exc})"
        print(f"running (pid {pid}), status={st['status']}{dim_s}")
    except (OSError, RuntimeError) as exc:
        print(f"running (pid {pid}) but QMP unreachable: {exc}")


# --------------------------------------------------------------------------
# interaction
# --------------------------------------------------------------------------
def do_shot(args):
    qmp = Qmp()
    path = screendump(qmp, args.path)
    try:
        w, h = png_dims(path)
        print(f"{path} ({w}x{h})")
    except RuntimeError as exc:
        print(f"{path} -- WARNING: {exc}")


def do_key(args):
    qmp = Qmp()
    for spec in args.keys:
        send_keys(qmp, parse_combo(spec), hold=args.hold)
        time.sleep(args.delay)
    print(f"sent {len(args.keys)} key event(s)")


def do_type(args):
    qmp = Qmp()
    text = args.text
    if args.enter:
        text += "\n"
    for ch in text:
        send_keys(qmp, char_to_keys(ch), hold=args.hold)
        time.sleep(args.delay)
    print(f"typed {len(text)} char(s)")


def do_click(args):
    qmp = Qmp()
    dims = current_dims(qmp)
    move_mouse(qmp, args.x, args.y, dims)
    time.sleep(0.15)
    presses = 2 if args.double else 1
    for i in range(presses):
        qmp.cmd("input-send-event", events=[
            {"type": "btn", "data": {"down": True, "button": args.button}}])
        time.sleep(0.05)
        qmp.cmd("input-send-event", events=[
            {"type": "btn", "data": {"down": False, "button": args.button}}])
        if i == 0 and presses > 1:
            time.sleep(0.08)
    print(f"{'double-' if args.double else ''}clicked {args.button} at "
          f"({args.x},{args.y}) on {dims[0]}x{dims[1]}")


def do_move(args):
    qmp = Qmp()
    dims = current_dims(qmp)
    move_mouse(qmp, args.x, args.y, dims)
    print(f"moved to ({args.x},{args.y})")


def do_scroll(args):
    qmp = Qmp()
    button = "wheel-up" if args.direction == "up" else "wheel-down"
    for _ in range(args.count):
        qmp.cmd("input-send-event", events=[
            {"type": "btn", "data": {"down": True, "button": button}}])
        qmp.cmd("input-send-event", events=[
            {"type": "btn", "data": {"down": False, "button": button}}])
        time.sleep(0.05)
    print(f"scrolled {args.direction} x{args.count}")


def do_watch(args):
    """Screenshot repeatedly until two consecutive frames are identical."""
    import hashlib
    qmp = Qmp()
    prev = None
    deadline = time.time() + args.timeout
    stable_since = None
    while time.time() < deadline:
        path = screendump(qmp, args.path)
        digest = hashlib.sha256(open(path, "rb").read()).hexdigest()
        if digest == prev:
            if stable_since is None:
                stable_since = time.time()
            if time.time() - stable_since >= args.stable:
                print(f"screen stable for {args.stable}s -> {path}")
                return
        else:
            stable_since = None
        prev = digest
        time.sleep(args.interval)
    print(f"WARNING: screen never settled within {args.timeout}s -> {args.path}")


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("start", help="boot a headless VM")
    s.add_argument("--iso", help="attach this ISO and boot from it")
    s.add_argument("--disk", default=os.path.join(RUNDIR, "ionix-test.qcow2"))
    s.add_argument("--efivars", default=os.path.join(RUNDIR, "efivars.fd"))
    s.add_argument("--fresh-disk", action="store_true",
                   help="delete and recreate the disk and EFI vars first")
    s.add_argument("--size", default="64G")
    s.add_argument("--memory", default="8G")
    s.add_argument("--cpus", default="4")
    s.add_argument("--width", default="1920")
    s.add_argument("--height", default="1080")
    s.add_argument("--rendernode", default="/dev/dri/renderD128")
    s.add_argument("--forward", action="append", default=[], metavar="HOST:GUEST",
                   help="forward a localhost TCP port to the guest, e.g. 2222:22 for ssh")
    s.add_argument("--headed", action="store_true",
                   help="show the VM in a window on the host desktop (2D only)")
    s.add_argument("--gl", action="store_true",
                   help="use virtio-vga-gl/egl-headless (faster guest GL, but "
                        "screendump stops working once the guest takes over)")
    s.set_defaults(func=do_start)

    s = sub.add_parser("shot", help="write a PNG screenshot")
    s.add_argument("path")
    s.set_defaults(func=do_shot)

    s = sub.add_parser("watch", help="screenshot until the screen stops changing")
    s.add_argument("path")
    s.add_argument("--timeout", type=float, default=300)
    s.add_argument("--interval", type=float, default=3)
    s.add_argument("--stable", type=float, default=6,
                   help="seconds of no change before declaring settled")
    s.set_defaults(func=do_watch)

    s = sub.add_parser("key", help="send key combos, e.g. ret ctrl-alt-f2 super-t")
    s.add_argument("keys", nargs="+")
    s.add_argument("--hold", type=int, default=80)
    s.add_argument("--delay", type=float, default=0.12)
    s.set_defaults(func=do_key)

    s = sub.add_parser("type", help="type a literal string")
    s.add_argument("text")
    s.add_argument("--enter", action="store_true", help="append Return")
    s.add_argument("--hold", type=int, default=40)
    s.add_argument("--delay", type=float, default=0.06)
    s.set_defaults(func=do_type)

    s = sub.add_parser("click")
    s.add_argument("x", type=int)
    s.add_argument("y", type=int)
    s.add_argument("--button", default="left", choices=["left", "right", "middle"])
    s.add_argument("--double", action="store_true")
    s.set_defaults(func=do_click)

    s = sub.add_parser("move")
    s.add_argument("x", type=int)
    s.add_argument("y", type=int)
    s.set_defaults(func=do_move)

    s = sub.add_parser("scroll")
    s.add_argument("direction", choices=["up", "down"])
    s.add_argument("count", nargs="?", type=int, default=3)
    s.set_defaults(func=do_scroll)

    s = sub.add_parser("powerdown", help="ACPI shutdown request")
    s.set_defaults(func=do_powerdown)

    s = sub.add_parser("wait-off", help="block until the VM process exits")
    s.add_argument("--timeout", type=float, default=300)
    s.set_defaults(func=do_waitoff)

    s = sub.add_parser("status")
    s.set_defaults(func=do_status)

    s = sub.add_parser("quit", help="force-stop the VM")
    s.set_defaults(func=do_quit)

    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
