# Neovim performance and Apollo LSP

The configuration keeps the existing leader (comma), Telescope navigation, NvimTree, completion keys, Rust formatting policy, and session restoration.

## What changed

- Bufferline is core UI: it loads at startup and always remains visible. Completion loads on insert; Telescope, NvimTree, and ToggleTerm load on demand. Other buffer decorations load when reading files.
- Snacks' duplicate dashboard and indentation rendering are disabled. Dashboard-nvim is explicitly prevented from hiding or restoring the tabline; bufferline owns that UI. Snacks picker shortcuts remain available.
- Startup either restores a session/opens the requested file or shows the dashboard. Dashboard auto-start is reserved for an empty launch with no saved session; `:Dashboard` remains available manually.
- The multi-GB generated `angle_debug.txt` is locally Git-excluded, which also keeps it out of normal ripgrep searches. The file is preserved; use an explicit filename to search it.
- Telescope grep no longer sorts ripgrep's file traversal, allowing parallel search. General picker resume remains available; LSP results are freshly requested for each symbol.
- `gI` and `,li` first look for overrides, then fall back to the symbol's definition when there are none. This covers ordinary non-virtual methods such as `ApolloSettings::getSettingValue`. Requests are asynchronous, with four in flight, cancellation, deadlines, and declaration fallback while indexing. Resolving a declaration temporarily opens its header document for clangd; newly created, unmodified hidden headers are cleaned up afterward. `:LspNavigationCancel` cancels an outstanding lookup.
- NvimTree shows Git-ignored files and follows the active file, updating its root when needed. Picker search exclusions remain separate from file-explorer visibility.
- NvimTree closes cleanly when the last editing window closes; the old window-closing `QuitPre` hook was replaced to avoid a quit hang.
- Session restoration runs after `VimEnter`, so restored files trigger filetype detection, bufferline, Tree-sitter, and LSP startup normally.
- LSP mappings are buffer-local. Rust virtual diagnostic lines are scoped to rust-analyzer namespaces.
- macOS uses `/usr/bin/clangd` (Apple clangd 21 on this machine). Other systems use `clangd` from PATH/Mason. `NVIM_CLANGD` overrides the executable. Background indexing uses four workers at low priority; `--log=error` avoids filling Neovim's LSP log with normal index traffic.
- clangd runs with `--clang-tidy=false` for daily editing. Compiler errors remain inline; warnings and hints remain available through gutter signs, underlines, diagnostic pickers, and `,ld` (line diagnostic details). `:ClangdTidyToggle` enables or disables clang-tidy for the session and restarts clangd. The project `.clang-tidy` and C++ sources are unchanged.

The original, already-modified configuration was backed up to `~/.local/state/nvim/config-backups/20260907-performance-lsp/`.

## Search, layout, and Telescope version

- Both Telescope and Snacks use a vertical layout with the preview above the results. Snacks provides the `Files` and `Grep` pickers on `,ff` and `,/`; `,fw` uses Telescope's grep-with-arguments extension.
- Both pickers display complete project-relative paths without replacing intermediate directories with ellipses.
- A single definition or implementation jumps directly to its destination. Multiple destinations open the picker.
- `,ff` searches filenames. Grep searches file contents: entering a filename there finds references to that filename, not necessarily the file itself.
- Paths containing `unittest` are excluded from search results unless the picker's search directory is `unittest/` or one of its descendants. This is evaluated for each search, including explicit picker `cwd` options. Use `:pwd` to check the current directory. File explorers remain available for navigating into the test tree.
- General picker caching is scoped to the search directory, so changing directories does not resume a search from the previous directory.
- Frecency automatic cleanup is disabled to avoid blocking history searches with stale-record deletion prompts. Existing history is preserved; use `:FrecencyValidate` when you want to review cleanup.
- Apollo's local `.ignore` makes `sdk-cxx/include/` searchable despite its Git ignore rule. Thus `sdk-cxx/include/ApolloSDK.cpp` and the native source both appear. Git still ignores the generated SDK copies; other ignored build trees remain excluded.

Telescope is upgraded from the 2024 `0.1.x` commit `a0bbec2` to the pinned upstream commit [`40aedd8`](https://github.com/nvim-telescope/telescope.nvim/commit/40aedd8a68c78a656a10a8d62d80c54af59420fb). This is newer than tagged release v0.2.1 and includes its Neovim compatibility fixes, plus a cached-finder replay fix: yield once per 1,000 entries, instead of on every entry. An instrumented 10,000-entry replay verified 10 scheduler yields versus 10,000 before; this is an operation-count check, not a wall-clock speedup claim. Native FZF sorting is retained.

Post-upgrade checks passed for both picker layouts, the exact `getSettingValue` call returning `ApolloSettings.cpp:865`, generated SDK file discovery, the 10-case search-policy integration test, and the FZF/live-grep-args/frecency extensions. The existing live-grep-args extension still emits a non-fatal `vim.tbl_flatten` deprecation notice on Neovim 0.12.

The pre-upgrade configuration/lockfile are saved in `~/.local/state/nvim/config-backups/20260907-telescope-upgrade/`. Restart Neovim after these configuration and plugin changes; existing sessions retain loaded Lua modules.

Useful built-in navigation tools include `:Telescope lsp_incoming_calls` and `:Telescope lsp_outgoing_calls` for exploring callers and callees.

## Apollo profiles

Open an Apollo source file, then use `:ApolloLspProfile` to choose a ready shared-code profile, or `:ApolloLspProfile android-arm64`. This restarts clangd. Platform-specific source directories keep their own database routing.

| Profile | Build information |
| --- | --- |
| `mac-arm64` (default) | 419 commands from the SDK makefile, configuration, and core toolchain flags |
| `ios-arm64` | 413 commands from the SDK makefile and iOS toolchain |
| Android | 469 commands exported by the NDK's compile-database target, including JNI |
| iOS SDK wrapper | 31 commands reconstructed from Xcode's resolved Debug settings, source build phase, and per-file flags |
| GUI | Existing `sdk-cxx/cxx_demo_source/gui/build/compile_commands.json` |
| Unit tests | 5,938 commands from an isolated CMake configuration |
| OHOS native | **Not ready:** CMake requires the absent `core/u3player_core/build-ffmpeg/ohos/debug/arm64/libffmpeg.so` |

The generated project `.clangd` selects these databases. The old root `compile_commands.json` is preserved. Generated files are under `.cache/lsp/`, and only successful exports are selectable. Do not merge different platforms' commands for the same shared source into one database.

Three test directories are excluded only while their referenced source files are absent:

- `platform/common/gl/GLFilterHelper` and `engine/ApolloSettings`: missing `unittest/native/stubs/VideoFilterManager_stub.cpp`.
- `engine/asr/WebSocketASRService`: missing `native/engine/src/asr/WebSocketASRService.cpp`.

The list is recorded in `.cache/lsp/tests/excluded-targets.json`. The exporter automatically includes these directories once their missing files exist. Production files retain production flags even when a test target also compiles them.

The main/core checkouts currently use different build-script layouts. The make exporter reads the existing legacy `config.ini` defaults when `config_base.ini` is absent, and uses the core's `compile_utils.sh` when the main makefile's renamed `utils_compiler_flags.sh` is absent. It does not modify either build system or run the packaging pipeline.

## Refresh after changing sources, flags, SDKs, or branches

From any directory:

```sh
rtk proxy python3 "$HOME/.config/nvim/scripts/apollo_lsp.py" \
  "$HOME/workspace/apollo/u3player4" --platform mac --tests --xcode --activate
rtk proxy python3 "$HOME/.config/nvim/scripts/apollo_lsp.py" \
  "$HOME/workspace/apollo/u3player4" --platform ios
rtk proxy python3 "$HOME/.config/nvim/scripts/apollo_lsp.py" \
  "$HOME/workspace/apollo/u3player4" --platform android
```

After all exports, run `:ApolloLspProfile mac-arm64` to refresh routing and restart clangd. Refresh the GUI database through its usual CMake configure step if GUI build settings change.

OHOS can be exported with `--platform ohos` after its actual build dependencies are available. The exporter intentionally fails instead of creating fake libraries to bypass CMake's checks. Full FFmpeg-source indexing also needs the core repository's own compilation database; the engine profiles provide the headers used by the player build.

The exporter runs build configuration and database generation, not compilation or linking. Unit-test export supplies Homebrew's cellar path on macOS and uses `.cache/lsp/tests` rather than the normal test build directory.

## Other languages

- Python: Pyright; project-local `pyrightconfig.json` selects `.venv` and limits scanning to build tooling.
- Shell: bash-language-server and ShellCheck.
- CMake: cmake-language-server.
- Java: JDT LS, with a distinct workspace per project root. `JDTLS_JAVA_HOME` overrides its runtime; on this Mac it uses Android Studio's bundled Java 21. The legacy `sdk-java` import uses Gradle 7.5.1/JDK 17, consistent with the build pipeline, without editing the wrapper. JDT's generated project metadata is locally Git-excluded.
- Standard TypeScript/JavaScript: typescript-language-server; JSON: vscode-json-language-server.
- `.ets`: standalone `@fe-essential/arkts-lsp` 0.1.4. Hover was verified in `ApolloSDK.ets`. This is community ArkTS support, not full DevEco SDK/type-checking parity. The bundled DevEco service uses a proprietary notification protocol and is not enabled as a standard LSP.

Mason installs the standard language servers automatically. For a fresh machine, also install the external tool and ArkTS package:

```sh
rtk proxy nvim --headless -i NONE '+MasonInstall shellcheck' +qa
rtk proxy npm install --prefix "$HOME/.local/share/nvim/arkts-lsp" @fe-essential/arkts-lsp@0.1.4
```

Mason's cmake-language-server 0.1.11 currently permits incompatible pygls 2.x. This installation pins its isolated environment to pygls 1.3.1. Reapply after reinstalling that server if the upstream package still has this issue:

```sh
rtk proxy "$HOME/.local/share/nvim/mason/packages/cmake-language-server/venv/bin/python" \
  -m pip install pygls==1.3.1
```

## Verification

Representative GL, MediaPlayer, Android decoder, Android JNI, iOS wrapper, and GL unit-test files passed `clangd --check` without parser errors. These flag checks used `--clang-tidy=false`, now also the default for editing. Enable clang-tidy with `:ClangdTidyToggle` for an explicit lint pass. Initial background indexing still takes time, and unopened-file reference coverage grows as it completes.

The real `gI` check returned six overrides, including two source bodies and four declaration fallbacks while the index was warming. Profile switching to Android and back to macOS passed.

Live Neovim checks verified clangd, Pyright, bashls, CMake, JDT LS, and ArkTS attachment; C++, Python, shell, and Java returned document symbols, and ArkTS returned class hover. Use `:checkhealth vim.lsp`, `:Mason`, and `:LspLog` for troubleshooting.

The navigation regression test runs without plugins or language-server processes:

```sh
cd "$HOME/.config/nvim"
rtk proxy nvim --headless -u NONE -i NONE -l tests/lsp_navigation.lua
```

File/grep policy integration checks exercise both pickers, nested test directories, and Git-ignored SDK sources:

```sh
rtk proxy nvim --headless -i NONE '+luafile tests/search_policy.lua'
```

Startup checks use an isolated temporary project/session. They verify rendered bufferline content, syntax/LSP activation, and selection of the active file in NvimTree, including Git-ignored SDK sources. On POSIX, session checks also run in a real terminal because headless startup skips dashboard behavior:

```sh
rtk proxy python3 tests/startup_ui.py
```
