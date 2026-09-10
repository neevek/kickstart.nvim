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

Adjust `program`, `cwd` and `args` to the project's binary and runtime resources. `lldb-dap` is also accepted as the adapter type. nvim-dap reads this file automatically when starting a session; no sourcing or manual import is needed. The custom build integration below adds support for `preLaunchTask`.

## Build and Launch

Select **Build and Launch Apollo Demo (macOS / Windows / Android)** with `F5` / `,dc`. The build opens in a terminal pane; launch proceeds only after every task succeeds. Failure retains the terminal output and aborts launch. `:DapBuildCancel` cancels the running build and prevents launch. Plain Launch and Attach profiles continue to reuse existing binaries.

Project `.vscode/tasks.json` defines the commands; `.vscode/launch.json` selects the final task through `preLaunchTask`:

| Platform | Build sequence |
| --- | --- |
| macOS | Canonical `sonic_build_cxx.py --config config_mac.ini` engine build, then Debug CMake GUI build in the original build directory |
| Windows | Canonical `sonic_build_cxx.py --config config_windows.ini` engine build, then `build.bat build Debug` |
| Android | Gradle `:demo_source:assembleDebug`, including native project dependencies, then `adb install -r -t`, followed by launch and LLDB attach |

The platform configs determine native build options and architecture. Android's task passes the absolute `config_android.ini` path, and the native build exports symbols to `sdk-android/AndroidDemo/obj/arm64-v8a`. Use a compatible JDK (Java 17 for this Gradle 7.5.1 project) before starting Neovim. Windows requires its normal native Python/MSVC/Git Bash build environment. With multiple Android devices, set `ANDROID_SERIAL` for the install task and use the same device in the launch profile.

For other projects, add a `type: "process"` task with `command`, `args`, optional `options.cwd` / `options.env`, and reference its label from `preLaunchTask`. The integration supports `dependsOn` labels, runs dependencies sequentially, and honors `osx` / `windows` / `linux` overrides. `${workspaceFolder}` and `${env:NAME}` are expanded. Shell/background tasks and problem-matcher parsing are not implemented; use an explicit shell executable as a process task when needed. Commands should return nonzero on failure.

The task graphs and generic execution/failure handling were tested; full Apollo engine builds and APK installation were not run as part of configuring these profiles.

## Apollo demo on this Mac

The local `u3player4/.vscode/launch.json` contains **Launch Apollo Demo (macOS)** and **Attach to Apollo Demo (macOS)**, alongside the existing Windows configuration. The global Neovim config contains no Apollo-specific debugger paths.

Build or refresh the GUI from the project root:

```sh
cd ~/workspace/apollo/u3player4
cmake -S sdk-cxx/cxx_demo_source/gui -B sdk-cxx/cxx_demo_source/gui/build \
  -DCMAKE_BUILD_TYPE=Debug -DCMAKE_OSX_ARCHITECTURES=arm64
cmake --build sdk-cxx/cxx_demo_source/gui/build --target apolloplayer -j 4
nvim sdk-cxx/cxx_demo_source/gui/main.cpp
```

Press `F5` / `,dc` and select **Launch Apollo Demo (macOS)**. It opens the demo immediately unless a breakpoint is hit. The normal build stages the executable in `sdk-cxx/build`. This profile runs `sdk-cxx/build/apolloplayer` with `sdk-cxx/build` as its working directory for staged libraries and resources. Add a media path in the profile's `args` to launch with a video.

The GUI Debug build is available. The separately loaded `sdk-cxx/build/libu3player.dylib` still comes from an older engine build: LLDB reports a stale debug-map object for `ApolloSettings.o`. Rebuild and stage the engine and its matching symbols before expecting reliable debugging of recently edited engine code. Rebuilding the GUI alone does not rebuild that dylib. Keep matching object files or a generated dSYM available; optimized code can also skip lines or hide variables.

## Windows native debugging

The project profiles **Launch Apollo Demo (Windows)** and **Attach to Apollo Demo (Windows)** use the configured `lldb` adapter. Launch runs `${workspaceFolder}/sdk-cxx/build/apolloplayer.exe` with empty arguments and that directory as the working directory. Attach opens a process picker. On Windows, provide `lldb-dap.exe` on PATH or set `NVIM_LLDB_DAP`; keep matching PDB/debug symbols available. These Windows profiles have been configuration-checked on macOS, but have not been runtime-tested on a Windows host. See [LLDB platform support](https://lldb.llvm.org/).

## Android native debugging

The `android-lldb` adapter attaches to a running debuggable Android app over ADB. It detects the app's ABI, installs a temporary NDK `lldb-server` under the app's own UID, forwards a private debugger socket, and removes its temporary files and forward when the session ends. No root is needed. It uses the same LLDB panels and shortcuts as desktop debugging. Symbols load on demand, with LLDB's index cache enabled to reduce repeated indexing.

For Apollo, select **Launch Apollo Demo (Android)** to restart the installed app, resolve its launcher activity automatically, and attach LLDB. No APK build or installation is performed. This launches the app before attaching, so very early native initialization can run before breakpoints are installed. For an existing process, open **com.apollo.demo** on the device, start Neovim from `u3player4`, and select **Attach to Apollo Demo (Android)** with `F5` / `,dc`. Set native breakpoints with `,db`, then exercise the relevant feature on the phone. Attach resumes automatically; it does not set a breakpoint at `main`. Use `,dd` to detach and leave the app running; `,dt` terminates the debugged process.

The profile points LLDB at `sdk-android/AndroidDemo/obj/arm64-v8a`. The installed APK's `libu3player.so` and that local debug library were checked to have matching build ID `da9f3a59018443d2f41df712881f094a2de6eefd`. Recheck after changing builds. A pending breakpoint can become resolved when the app loads the native library. Source files edited after the binary was built still require a rebuild.

For another project, add a profile to `.vscode/launch.json`:

```json
{
  "name": "Android native attach",
  "type": "android-lldb",
  "request": "attach",
  "android": { "package": "com.example.app" },
  "stopOnEntry": false,
  "initCommands": [
    "settings set target.exec-search-paths \"${workspaceFolder}/path/to/unstripped/arm64-v8a\""
  ]
}
```

Use `"request": "launch"` to launch/restart instead of attach. Optionally set `android.activity` to a component such as `com.example.app/.MainActivity`; otherwise the launcher is resolved automatically. Launch refuses to restart a process that already has a native debugger attached.

Set `android.serial` if several devices are connected. Set `android.process` to an exact process name such as `com.example.app:player` when native playback runs in a service process. `android.package` remains the owning app package for `run-as`. Match the symbols to the installed library and use `sourceMap` if its build machine had different source paths.

Requirements: Python 3.9+, `adb` on PATH, an authorized device, an installed debuggable app (already running for attach), an Android NDK, and `lldb-dap` with Android support (Xcode's is used here). The adapter discovers NDK servers under `ANDROID_SDK_ROOT` / `ANDROID_HOME`, falling back to `~/Library/Android/sdk`; `NVIM_ANDROID_LLDB_SERVER` overrides the device server binary. `NVIM_LLDB_DAP` overrides the host adapter. Java/Kotlin debugging needs a separate adapter.

Android logcat now streams into the standalone log viewer, filtered to the selected device and app PID. It stops on detach or process exit; set `android.logcat=false` to disable it. Native desktop stdout/stderr also use the log viewer; debugger console messages and expression results remain in the DAP REPL. See [LOG_VIEWER.md](LOG_VIEWER.md).

If attachment fails, check `:DapShowLog`, `adb devices`, and `adb shell run-as <package> id`. Android LLDB emits stopped events for several threads at once; this adapter disables nvim-dap's automatic continuation of secondary threads so a breakpoint remains stopped.

## Verification

`python3 tests/debug_smoke.py` builds a temporary C++ program and exercises the actual installed adapter: project profile discovery, source breakpoint, expression evaluation, step over and successful exit. It also verifies that normal editor startup leaves DAP unloaded.

During the Android setup, this desktop smoke check encountered a macOS LLDB-DAP launch failure (signal 9 before the breakpoint). It also reproduces with `nvim -u NONE` and only nvim-dap, while the LLDB CLI launches the same fixture successfully. The Android device checks below pass; the desktop DAP failure remains unresolved.

`python3 tests/android_adapter.py` uses fake ADB and LLDB executables to verify that setup preserves the DAP input stream and cleans up forwards and temporary files on success and setup failure.

Run `nvim --headless -u NONE -n -i NONE '+luafile tests/debug_build.lua'` to check build ordering, paths containing spaces, failure gating and terminal cleanup. `tests/android_logcat.lua` uses the same invocation to check device/PID selection, streaming, detach and opt-out with a fake logcat process.

On the connected ARM64 device, Neovim was verified against `com.apollo.demo`: attach, a native function breakpoint in `__epoll_pwait`, 36 threads, resolved stack frames, expression evaluation, and detach. After detach the app was running (`TracerPid: 0`, state `S`) and the ADB forward list was empty. The wrapper clears a lingering Android attach SIGSTOP only when the original process identity still matches and its tracer has exited. Apollo engine playback breakpoints have not yet been exercised; the matching debug symbols are configured.

Apollo's source debugging was verified at `main.cpp:183`, with `argc` evaluated as `2`. The default launch now runs without this automatic breakpoint. Playback and current engine symbols require separate validation. A separate native process test also verified attach, variable evaluation, and detach with the process still running.
