# Live log viewer

Press `,lv` or run `:LogView` to choose a source or reopen a capture from this editor session. No debugger is required.

```vim
:Logcat com.apollo.demo
:Logcat
:LogCommand your-command --your-args
:LogFile /path/to/application.log
```

Logcat without a package captures all logs on the selected device. A package/process name selects its current PID; reopen the source if that process restarts. Multiple devices prompt for selection. LogCommand executes the command using Neovim's configured shell. LogFile uses Python 3 to follow append, truncation and rotation, initially reading the last 128 KiB.

Inside the viewer:

| Key | Action |
| --- | --- |
| `f` | Live include-regex input |
| `e` | Live exclude-regex input |
| `s` | Minimum severity |
| `r` | Toggle existing filters between literal and regex |
| `p` | Freeze/resume the display; capture continues |
| `G` | Resume display and follow newest output |
| `o` | Open the complete saved capture |
| `x` | Stop this capture |
| `C` / `:LogClear` | Clear the viewer's history and resume following; retain the capture file |
| `q` | Hide the window while capture continues |
| `?` | Key help |

The regex popup updates results while typing (60 ms debounce), without Enter. Enter keeps the filter; Escape restores the previous filters. Incomplete/invalid regexes keep the last valid results and show an inline warning. Filters use **Vim regex** syntax: `error\|timeout` matches either word; `\cerror` ignores case. Clearing the input removes that filter. Opening either live filter switches filtering to regex mode. Unrecognized severity is treated as INFO.

The viewer retains the latest 50,000 lines per source in memory. Filter changes apply to that retained history and incoming messages. The complete captured stream is saved separately under `stdpath('state')/logview/`; `o` opens it for searching older messages. Raw capture files are retained across restarts and are not automatically deleted. The active/recent-source menu is scoped to the current Neovim process.

Output is batched at 100 ms, and hidden/paused views are not redrawn. A line without a newline is buffered until complete; unusually long partial lines are bounded in the display, with raw output preserved in the capture file. Following keeps the newest line at the bottom of the text area. Scrolling away freezes the displayed snapshot while capture continues; scrolling back to its bottom resumes following and catches up. `G` resumes immediately. `p` remains an explicit display-pause toggle.

During Android debugging, logcat opens here automatically and stops on detach. Desktop LLDB stdout/stderr also route here; debugger commands and evaluation results remain in the REPL. Independently started sources keep running until stopped with `x` or Neovim exits. Integrated terminal output is not intercepted.

Start debugging normally with `F5` / `,dc` and choose a launch/attach profile. No additional log-viewer setup is required. Android opens a PID-filtered viewer on attachment; desktop LLDB opens one when stdout/stderr arrives. If hidden with `q`, use `,lv` and select the existing capture to reopen it. Use `f` / `e` there for live filters. Clearing history preserves the filters and continues capture; old lines remain available in the complete capture file through `o`.
