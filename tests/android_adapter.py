"""Check the Android wrapper's DAP stream isolation and resource cleanup."""
import json
import os
from pathlib import Path
import subprocess
import tempfile


repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="android-dap-test-") as directory:
    root = Path(directory)
    adb = root / "adb"
    adb.write_text("""#!/usr/bin/env python3
import json, os, pathlib, sys, time
# If setup accidentally inherits stdin, this consumes the debugger's initialize packet.
sys.stdin.buffer.read()
args = sys.argv[1:]
with open(os.environ['ADB_TEST_LOG'], 'a') as f: f.write(json.dumps(args) + '\\n')
if args[0] == '-s': args = args[2:]
if args == ['devices']: print('List of devices attached\\ndevice-1\\tdevice')
elif args[0] == 'pull': pathlib.Path(args[-1]).write_text('test executable')
elif args[:2] == ['forward', 'tcp:0']: print('45678')
elif args[:2] == ['shell', 'pidof']: print('1234')
elif args[:2] == ['shell', 'getprop']: print('arm64-v8a')
elif args[:4] == ['shell', 'cmd', 'package', 'resolve-activity']: print('com.example.app/.MainActivity')
elif args[:2] == ['shell', 'run-as']:
    command = args[-1]
    if 'readlink' in command: print('/system/bin/app_process64')
    elif '/stat' in command and '/status' not in command:
        calls = pathlib.Path(os.environ['ADB_TEST_LOG']).read_text().splitlines()
        reads = sum('/stat' in line and '/status' not in line for line in calls)
        state = 'S' if reads == 1 else 'T'
        birth = '200' if reads > 1 and os.environ.get('ADB_TEST_REUSED_PID') else '100'
        print('1234 (app) ' + state + ' ' + '0 ' * 18 + birth)
    elif '/status' in command: print('TracerPid: 0')
    elif 'exec cache/' in command:
        if os.environ.get('ADB_TEST_FAIL'): sys.exit(1)
        time.sleep(30)
    elif 'test -s' in command and not os.environ.get('ADB_TEST_FAIL'): print('ready')
""")
    adapter = root / "lldb-dap"
    adapter.write_text("""#!/usr/bin/env python3
import sys
sys.stdout.buffer.write(sys.stdin.buffer.read())
""")
    adb.chmod(0o755)
    adapter.chmod(0o755)
    server = root / "lldb-server"
    server.touch()
    command_file = root / "attach.lldb"
    log = root / "adb.jsonl"
    env = {**os.environ, "PATH": str(root) + os.pathsep + os.environ['PATH'],
           "NVIM_ANDROID_LLDB_SERVER": str(server), "ADB_TEST_LOG": str(log)}
    command = ["python3", str(repo / "scripts/android_lldb.py"), "--package", "com.example.app",
               "--lldb-dap", str(adapter), "--command-file", str(command_file)]
    packet = b'Content-Length: 24\r\n\r\n{"command":"initialize"}'
    for failed, reused_pid, launch in ((False, False, False), (True, False, False), (False, True, False), (False, False, True)):
        run_env = {**env, **({"ADB_TEST_FAIL": "1"} if failed else {}),
                   **({"ADB_TEST_REUSED_PID": "1"} if reused_pid else {})}
        result = subprocess.run(command + (["--launch"] if launch else []), input=packet,
                                capture_output=True, env=run_env, timeout=20)
        assert (result.returncode != 0) == failed, result.stderr.decode()
        if not failed:
            assert result.stdout == packet, "ADB consumed or corrupted the DAP input stream"
        calls = [json.loads(line) for line in log.read_text().splitlines()]
        started = any(call[2:5] == ['shell', 'am', 'start'] for call in calls)
        assert started == launch, 'Attach must not restart the app; launch must start it'
        assert ["-s", "device-1", "forward", "--remove", "tcp:45678"] in calls
        resumed = any('kill -CONT 1234' in call[-1] for call in calls)
        assert resumed != reused_pid, 'Only the original process should be resumed after detach'
        assert not command_file.exists() and not Path(str(command_file) + '.exe').exists()
        log.unlink()
    print("Android adapter: DAP stream preserved; success/failure cleanup passed")
