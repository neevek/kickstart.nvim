"""Exercise native launch.json discovery, breakpoint, evaluation, stepping and exit."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="nvim-debug-test-") as directory:
    # macOS /var aliases /private/var; debug info must match Neovim's canonical path.
    root = Path(directory).resolve()
    source = root / "main.cpp"
    source.write_text("""int add(int a, int b) {
    int result = a + b;
    return result;
}
int main() {
    int value = add(19, 23);
    return value == 42 ? 0 : 1;
}
""")
    compiler = shutil.which("clang++") or shutil.which("c++")
    assert compiler, "Install a C++ compiler to run this test"
    subprocess.run([compiler, "-g", "-O0", str(source), "-o", str(root / "app")],
                   cwd=root, check=True)
    (root / ".vscode").mkdir()
    (root / ".vscode/launch.json").write_text(json.dumps({
        "version": "0.2.0",
        "configurations": [{"name": "Native smoke", "type": "lldb", "request": "launch",
                            "program": "${workspaceFolder}/app", "cwd": "${workspaceFolder}",
                            "stopOnEntry": False}],
    }))
    output = root / "result.json"
    proc = subprocess.run(
        ["nvim", "--headless", "-n", "-R", "-i", "NONE", str(source),
         "+luafile " + str(repo / "tests/debug_smoke.lua")],
        cwd=root, env={**os.environ, "NVIM_DAP_RESULT": str(output)},
        capture_output=True, text=True, timeout=25,
    )
    assert proc.returncode == 0, proc.stderr
    result = json.loads(output.read_text())
    assert result.get("stops") == ["breakpoint", "step"], result
    assert result["frame"]["path"] == str(source) and result["frame"]["line"] == 2, result
    assert result.get("evaluation") == "42" and result.get("step_line") == 3, result
    assert result.get("exitCode") == 0 and not result.get("timeout"), result
    assert not result.get("error") and not result.get("evaluate_error"), result
    print("Native debugger: lazy startup, project profile, breakpoint, evaluation, step and clean exit passed")
