" Line-local severity highlighting for plain-text debugger output.
" No history rescans or per-message Lua callbacks are needed for streaming logs.
syntax match DebugLogTrace /^.*\%(\[\%(V\|VERBOSE\|T\|TRACE\)\]\|\<\%(VERBOSE\|TRACE\)\>[: ]\).*$/
syntax match DebugLogDebug /^.*\%(\[\%(D\|DEBUG\)\]\|\<DEBUG\>[: ]\).*$/
syntax match DebugLogInfo /^.*\%(\[\%(I\|INFO\)\]\|\<INFO\>[: ]\).*$/
syntax match DebugLogWarn /^.*\%(\[\%(W\|WARN\|WARNING\)\]\|\<\%(WARN\|WARNING\)\>[: ]\).*$/
syntax match DebugLogError /^.*\%(\[\%(E\|ERROR\|F\|FATAL\)\]\|\<\%(ERROR\|FATAL\)\>[: ]\).*$/

highlight default link DebugLogTrace Comment
highlight default link DebugLogDebug DiagnosticHint
highlight default link DebugLogInfo DiagnosticInfo
highlight default link DebugLogWarn DiagnosticWarn
highlight default link DebugLogError DiagnosticError
