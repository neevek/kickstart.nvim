#!/usr/bin/env python3
"""Run lldb-dap with a private Android gdbserver and clean up its ADB forward."""
import argparse
import os
from pathlib import Path
import re
import shlex
import shutil
import signal
import subprocess
import sys
import time
import uuid


def server_path(abi):
    override = os.environ.get("NVIM_ANDROID_LLDB_SERVER")
    if override:
        return Path(override).expanduser()
    arch = {"arm64-v8a": "aarch64", "armeabi-v7a": "arm", "x86": "i386", "x86_64": "x86_64"}.get(abi)
    if not arch:
        raise RuntimeError("Unsupported Android ABI: " + abi)
    sdk = Path(os.environ.get("ANDROID_SDK_ROOT") or os.environ.get("ANDROID_HOME") or
               str(Path.home() / "Library/Android/sdk"))
    candidates = list(sdk.glob("ndk/*/toolchains/llvm/prebuilt/*/lib/clang/*/lib/linux/" + arch + "/lldb-server"))
    if candidates:
        return max(candidates, key=lambda p: tuple(int(n) for n in re.findall(r"\d+", str(p.relative_to(sdk)))))
    raise RuntimeError("Install an Android NDK or set NVIM_ANDROID_LLDB_SERVER")


class AndroidSession:
    def __init__(self, args):
        self.args = args
        self.adb = shutil.which("adb")
        if not self.adb:
            raise RuntimeError("adb is not on PATH")
        self.base = [self.adb]
        self.name = "nvim-lldb-" + uuid.uuid4().hex[:12]
        self.remote = "cache/" + self.name
        self.staged = "/data/local/tmp/" + self.name
        self.port = None
        self.server = None
        self.remote_created = False
        self.pid = None
        self.original_stat = None

    def call(self, *args, check=True, timeout=20):
        # stdin belongs to the DAP client; adb shell must never consume its packets.
        proc = subprocess.run(self.base + list(args), stdin=subprocess.DEVNULL,
                              capture_output=True, text=True, timeout=timeout)
        if check and proc.returncode:
            raise RuntimeError((proc.stderr or proc.stdout).strip())
        return proc.stdout.strip()

    def app_shell(self, command, **kwargs):
        return self.call("shell", "run-as", self.args.package, "sh", "-c", shlex.quote(command), **kwargs)

    def process_stat(self):
        stat = self.app_shell("cat /proc/" + self.pid + "/stat", check=False)
        fields = stat.rsplit(")", 1)[-1].split()
        return (fields[0], fields[19]) if len(fields) >= 20 else None

    def prepare(self):
        devices = [line.split()[0] for line in self.call("devices").splitlines()[1:]
                   if len(line.split()) >= 2 and line.split()[1] == "device"]
        serial = self.args.serial
        if not serial:
            if len(devices) != 1:
                raise RuntimeError("Connect one authorized device, or set android.serial in launch.json")
            serial = devices[0]
        if serial not in devices:
            raise RuntimeError("Android device is not online: " + serial)
        self.base += ["-s", serial]
        self.call("shell", "run-as", self.args.package, "id")
        pid = self.call("shell", "pidof", self.args.process or self.args.package, check=False).split()
        if len(pid) != 1:
            raise RuntimeError("Open the Android app first; expected one running process for " +
                               (self.args.process or self.args.package))
        if not pid[0].isdigit():
            raise RuntimeError("Invalid Android PID")
        self.pid = pid[0]
        self.original_stat = self.process_stat()
        # The process ABI can differ from the device ABI (32-bit app on a 64-bit phone).
        executable = self.app_shell("readlink /proc/" + pid[0] + "/exe")
        abi = self.call("shell", "getprop", "ro.product.cpu.abi")
        if "64" not in executable:
            abi = "armeabi-v7a" if "arm" in abi else "x86"
        server = server_path(abi)
        if not server.is_file():
            raise RuntimeError("Missing lldb-server: " + str(server))
        self.call("pull", executable, self.args.command_file + ".exe")
        self.remote_created = True
        self.call("push", str(server), self.staged)
        self.app_shell("mkdir -p " + self.remote + "; cp " + self.staged + " " + self.remote +
                       "/lldb-server && chmod 700 " + self.remote + "/lldb-server")
        self.call("shell", "rm", "-f", self.staged)
        self.port = self.call("forward", "tcp:0", "localabstract:" + self.name)
        command = ("echo $$ > " + self.remote + "/pid; exec " + self.remote +
                   "/lldb-server gdbserver --pipe 3 --attach " + pid[0] + " unix-abstract://" + self.name +
                   " 3>" + self.remote + "/ready")
        self.server = subprocess.Popen(self.base + ["shell", "run-as", self.args.package, "sh", "-c",
                                       shlex.quote(command)], stdin=subprocess.DEVNULL,
                                       stdout=sys.stderr, stderr=sys.stderr)
        # Wait for the Unix socket without consuming its single debugger connection.
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if self.server.poll() is not None:
                raise RuntimeError("Android lldb-server exited before connecting; see :DapShowLog")
            if self.app_shell("test -s " + self.remote + "/ready && echo ready", check=False) == "ready":
                break
            time.sleep(0.1)
        else:
            raise RuntimeError("Android lldb-server did not open its socket")
        Path(self.args.command_file).write_text("gdb-remote 127.0.0.1:" + self.port + "\n")
        print("Android debugger: " + self.args.package + " PID " + pid[0] + " on " + serial,
              file=sys.stderr, flush=True)
        return serial

    def close(self):
        # Only terminate our unique server, never the app or another debugger's server.
        if self.remote_created:
            command = ("if test -f " + self.remote + "/pid; then read p < " + self.remote +
                       "/pid; case $(cat /proc/$p/cmdline 2>/dev/null) in *" + self.remote +
                       "/lldb-server*) kill -TERM $p 2>/dev/null ;; esac; fi; rm -rf " + self.remote)
            try:
                self.app_shell(command, check=False, timeout=5)
                self.call("shell", "rm", "-f", self.staged, check=False, timeout=5)
            except (OSError, subprocess.TimeoutExpired):
                pass
        if self.server:
            try:
                self.server.wait(timeout=3)
            except subprocess.TimeoutExpired:
                self.server.terminate()
                self.server.wait(timeout=3)
        if self.port:
            try:
                self.call("forward", "--remove", "tcp:" + self.port, check=False, timeout=5)
            except (OSError, subprocess.TimeoutExpired):
                pass
        # Some Android kernels retain the attach SIGSTOP after LLDB detaches.
        # Resume only the same, originally running process after its tracer is gone.
        if self.server and self.original_stat and self.original_stat[0] not in ("T", "t"):
            try:
                current = self.process_stat()
                status = self.app_shell("cat /proc/" + self.pid + "/status", check=False, timeout=5)
                if (current and current == ("T", self.original_stat[1]) and
                        re.search(r"^TracerPid:\s+0$", status, re.MULTILINE)):
                    self.app_shell("kill -CONT " + self.pid, check=False, timeout=5)
            except (OSError, subprocess.TimeoutExpired):
                pass
        for path in (self.args.command_file, self.args.command_file + ".exe"):
            Path(path).unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", required=True)
    parser.add_argument("--process")
    parser.add_argument("--serial")
    parser.add_argument("--lldb-dap", required=True)
    parser.add_argument("--command-file", required=True)
    args = parser.parse_args()
    for value in (args.package, args.process, args.serial):
        if value and not re.fullmatch(r"[A-Za-z0-9_.:\-]+", value):
            parser.error("Invalid Android package, process, or serial")
    session = AndroidSession(args)
    proc = None
    def interrupted(signum, frame):
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, interrupted)
    try:
        serial = session.prepare()
        # DAP bytes pass directly between Neovim and LLDB; all setup logs go to stderr.
        proc = subprocess.Popen([args.lldb_dap], env={**os.environ, "ANDROID_SERIAL": serial})
        return proc.wait()
    except KeyboardInterrupt:
        return 130
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as exc:
        print("Android debugger: " + str(exc), file=sys.stderr)
        return 1
    finally:
        if proc and proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()
        session.close()


if __name__ == "__main__":
    sys.exit(main())
