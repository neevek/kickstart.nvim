vim.opt.rtp:prepend(vim.fn.getcwd())
vim.o.lines = 40
local s = require('custom.logview').new 'scroll'
assert(s.limit == 50000)
local data = {}
for i = 1, 50010 do
  data[i] = 'line ' .. i
end
s:feed(table.concat(data, '\n') .. '\n')
s:render()
assert(#s.lines == 50000 and s.lines[1] == 'line 11')
local win = vim.api.nvim_get_current_win()
assert(vim.fn.winline() == (vim.api.nvim_win_get_height(win) - 1), 'tail must occupy final row')
vim.cmd('normal! 20' .. string.char(25))
s:check_scroll()
assert(not s.follow, 'manual scroll must pause follow')
local top = vim.fn.winsaveview().topline
s:feed 'new line\n'
s:render()
assert(vim.fn.winsaveview().topline == top and vim.fn.getline '$' == 'line 50010', 'paused snapshot moved')
vim.cmd 'normal! G'
vim.cmd 'normal! zb'
s:check_scroll()
assert(s.follow, 'scrolling to bottom must resume')
s:render()
assert(vim.fn.getline '$' == 'new line')
assert(vim.fn.winline() == (vim.api.nvim_win_get_height(win) - 1))
s:stop()
print '50k history, bottom alignment, manual scroll pause and bottom resume passed'
vim.cmd 'qa!'
