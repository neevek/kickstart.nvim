# Native debugging in Neovim

The configuration supports launching and attaching to C, C++, Objective-C, Objective-C++, and Rust programs through LLDB. The debugger and panels load only when a debug command or shortcut is used. Other languages can add their own DAP adapters later.

On macOS, the adapter comes from `xcrun --find lldb-dap` in the selected Xcode installation. Elsewhere it uses `lldb-dap` on PATH. Set `NVIM_LLDB_DAP` to override the executable. The adapter is already available on this Mac.

## Everyday use

1. Build the program with debug symbols (`-g`, ideally without optimization, or CMake `Debug`).
2. Start Neovim from the project root and open a source file. `:pwd` shows the directory used to discover project profiles.
3. Set a breakpoint with `,db`.
4. Press `F5` or `,dc`, then choose a project profile or **Launch native executable** and select the built binary. **Attach to native process** offers a process picker.
5. Inspect variables and the call stack in the right sidebar. Use the bottom REPL for expressions or LLDB commands.

The REPL occupies the full bottom panel. The integrated console is hidden by default; if a launch uses terminal input/output, open it with `:lua require('dapui').float_element('console', { enter = true })`.

| Key | Action |
| --- | --- |
| `F5` / `,dc` | Start or continue |
| `,db` / `,dB` | Toggle breakpoint / conditional breakpoint |
| `F10` / `,dn` | Step over |
| `F11` / `,di` | Step into |
| `F12` / `,do` | Step out |
| `,de` | Evaluate the expression under the cursor or selected text |
| `,du` | Toggle debugger panels |
| `,dr` | Open REPL |
| `,dt` | Terminate the debugged program |
| `,dd` | Detach while leaving the program running |

Launch profiles run immediately with `stopOnEntry` set to false. No automatic breakpoint is added at `main`; execution pauses at your breakpoints or debugger stop conditions such as a crash.

Plain-text output in the DAP REPL is colored by severity: errors/fatal messages are red, warnings yellow, info blue, and debug/trace messages muted. This recognizes Apollo's `[E]`, `[W]`, `[I]`, `[D]` markers and full uppercase level names. It uses line-local syntax highlighting, so streaming output does not trigger Lua scans of the log history. The same rules apply to plain-text DAP console buffers; integrated terminals retain the application's own ANSI colors. To apply the rules to an already open REPL after installing this change, focus it and run `:set syntax=dap-repl`.

## Configuration for any project

Create `.vscode/launch.json` in the project's root:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "My app (LLDB)",
      "type": "lldb",
      "request": "launch",
      "program": "${workspaceFolder}/build/my-app",
      "cwd": "${workspaceFolder}",
      "args": [],
      "stopOnEntry": false
    },
    {
      "name": "Attach (LLDB)",
      "type": "lldb",
      "request": "attach",
      "pid": "${command:pickProcess}"
    }
  ]
}
```

Adjust `program`, `cwd` and `args` to the project's binary and runtime resources. `lldb-dap` is also accepted as the adapter type. nvim-dap reads this file automatically when starting a session; no sourcing or manual import is needed. It does not run VS Code `preLaunchTask` build tasks: build in a terminal before starting a new debug session.

## Apollo demo on this Mac

The local `u3player4/.vscode/launch.json` contains **Apollo Demo (macOS)** and **Attach to Apollo Demo (macOS)**, alongside the existing Windows configuration. The global Neovim config contains no Apollo-specific debugger paths.

Build or refresh the GUI from the project root:

```sh
cd ~/workspace/apollo/u3player4
cmake -S sdk-cxx/cxx_demo_source/gui -B .cache/nvim-dap/gui-debug \
  -DCMAKE_BUILD_TYPE=Debug -DCMAKE_OSX_ARCHITECTURES=arm64
cmake --build .cache/nvim-dap/gui-debug --target apolloplayer -j 4
nvim sdk-cxx/cxx_demo_source/gui/main.cpp
```

Press `F5` / `,dc` and select **Apollo Demo (macOS)**. It opens the demo immediately unless a breakpoint is hit. This profile runs `.cache/nvim-dap/gui-debug/apolloplayer` with `sdk-cxx/build` as its working directory for staged libraries and resources. Add a media path in the profile's `args` to launch with a video.

The GUI Debug build is available. The separately loaded `sdk-cxx/build/libu3player.dylib` still comes from an older engine build: LLDB reports a stale debug-map object for `ApolloSettings.o`. Rebuild and stage the engine and its matching symbols before expecting reliable debugging of recently edited engine code. Rebuilding the GUI alone does not rebuild that dylib. Keep matching object files or a generated dSYM available; optimized code can also skip lines or hide variables.

## Verification

`python3 tests/debug_smoke.py` builds a temporary C++ program and exercises the actual installed adapter: project profile discovery, source breakpoint, expression evaluation, step over and successful exit. It also verifies that normal editor startup leaves DAP unloaded.

Apollo's source debugging was verified at `main.cpp:183`, with `argc` evaluated as `2`. The default launch now runs without this automatic breakpoint. Playback and current engine symbols require separate validation. A separate native process test also verified attach, variable evaluation, and detach with the process still running.
