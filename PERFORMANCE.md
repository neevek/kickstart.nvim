# Further performance audit

Measured on this Mac with Neovim 0.12.5 and the installed, pinned plugins. Read-only launches used `-n -R -i NONE`; existing editor/debugger processes were left running.

## Measurements

- Initial startup samples (`--startuptime`, headless): Lua 229/109/122 ms; Apollo C++ 256/262/342 ms. These are startup-to-first-screen measurements, not LSP indexing completion or a terminal responsiveness benchmark.
- An instrumented C++ launch spent about 132 ms inside the initial `vim.treesitter.start`. The later Snacks quickfile invocation took 0.004 ms: this Neovim already makes repeated highlighting startup a no-op, so disabling quickfile would not remove the expensive work.
- Sample plugin initialization costs: Mason/LSP setup 38 ms, NvimTree 14 ms, bufferline 6 ms. These vary with caches and system load. Completion, Telescope, and DAP were absent from the initial loaded-plugin list.
- Vimscript profiling found roughly 3 ms in indentation detection, not a dominant bottleneck.

## Applied change

`lua/custom/treesitter.lua` now checks installed parsers and calls the installer only for missing languages. Previously the unconditional install call loaded tooling and rebuilt the parser registry even when nothing needed installing.

| Metric, opening `init.lua` | Before | After |
| --- | ---: | ---: |
| Loaded `nvim-treesitter.*` modules, including the root module | 7 | 2 |
| Lua heap after garbage collection, median of three launches | 5,725 KiB | 5,538 KiB |

This removes five modules and about 187 KiB of Lua heap in that scenario. It is a small reduction in startup work, not a large memory reduction for the whole editor and language servers.

Six interleaved before/after C++ startup runs had medians of 447 ms and 459 ms respectively. The total did **not** improve reliably; background system load and initial highlighting dominate this small cleanup. No overall startup-speedup claim is warranted.

## Validation and remaining limits

All six existing startup/UI checks passed, including real terminal session restoration, bufferline rendering, C++ highlighting, clangd attachment, and NvimTree following ignored files. Markdown, inline Markdown, Lua and Bash fenced-code parsing also passed.

The largest observed cold C++ cost is the initial highlighting setup. Query/parser work is reused within a session. Deferring it could move the delay past the initial draw, but would not eliminate the work and could make highlighting appear late. The audit does not justify changing that behavior or disabling working LSP/navigation features.

Large-file protections, native fuzzy sorting, asynchronous navigation, lazy completion/debugging, and batched logcat output are already configured. No plugin upgrades or search exclusions were added in this pass. Full interactive scrolling, large-session memory growth, and long-running logcat throughput were not benchmarked here.

## Restored bufferline diagnostic cache

At the user's request, the diagnostic cache is restored independently of the reverted grep and large-file changes. `custom.bufferline_diagnostics` reuses bufferline's diagnostic aggregation until diagnostics change, a buffer is wiped, or diagnostic visibility is toggled. Insert mode retains the plugin's existing freeze behavior.

The earlier synthetic benchmark used 20 buffers with 100 diagnostics each and 100 tabline renders. Full diagnostic scans fell from 100 to 1. Three warmed runs had median totals of 2,098 ms before and 1,476 ms after (about 30% lower for this benchmark, with substantial variance). This is not a whole-editor speedup claim.

Slowness persisted after the cache was removed from both disk and the active editor. At that time an Xcode build and a background event-capture process were consuming substantial CPU. This makes system contention a plausible contributor; it does not conclusively establish the cache's effect on interactive responsiveness.
