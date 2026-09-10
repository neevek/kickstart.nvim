vim.opt.rtp:prepend(vim.fn.getcwd())
local viewer = require 'custom.logview'
local source = viewer.new('fixture', { limit = 3 })
source:feed 'I/Tag: first\nE/Tag: sec'
source:feed 'ond\nW/Tag: third\nI/Tag: fourth\n'
source:render()
assert(#source.lines == 3 and source.lines[1] == 'E/Tag: second')
local function rows()
  return vim.api.nvim_buf_get_lines(source.buf, 0, -1, false)
end
source:filter('Tag', 'fourth', false, 4)
assert(#rows() == 2)
source:filter([[second\|fourth]], '', true, 1)
assert(#rows() == 2)
source:filter('', '', false, 1)
source.paused = true
source:feed 'E/Tag: fifth\n'
assert(rows()[3] == 'I/Tag: fourth', 'paused view must stay still')
source.paused = false
source:render()
assert(rows()[3] == 'E/Tag: fifth')
local input, win = source:live_filter 'include'
vim.api.nvim_buf_set_lines(input, 0, -1, false, { 'fifth' })
vim.api.nvim_exec_autocmds('TextChangedI', { buffer = input })
assert(vim.wait(1000, function()
  return source.include == 'fifth'
end))
assert(#rows() == 1 and rows()[1] == 'E/Tag: fifth', 'filter must update before Enter')
vim.api.nvim_buf_set_lines(input, 0, -1, false, { [[\(]] })
vim.api.nvim_exec_autocmds('TextChangedI', { buffer = input })
vim.wait(100, function()
  return false
end)
assert(source.include == 'fifth', 'invalid partial regex must retain last valid results')
local cancel = vim.fn.maparg('<Esc>', 'n', false, true).callback
cancel()
assert(source.include == '' and not vim.api.nvim_win_is_valid(win))
source:stop()
assert(table.concat(vim.fn.readfile(source.path), '\n'):find('I/Tag: first', 1, true), 'full capture lost evicted line')
local command = viewer.command({ 'python3', '-c', "import sys; print('I/Cmd: ready'); sys.stderr.write('E/Cmd: error\\n')" }, { open = false })
assert(vim.wait(5000, function()
  return command.closed
end))
local capture = table.concat(vim.fn.readfile(command.path), '\n')
assert(capture:find('I/Cmd: ready', 1, true) and capture:find('E/Cmd: error', 1, true))
vim.api.nvim_buf_delete(source.buf, { force = true })
assert(#source.lines == 0)
print 'Log viewer: bounded history, partial lines, filters, paused capture, full file and command output passed'
vim.cmd 'qa!'
