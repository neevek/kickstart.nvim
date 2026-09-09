vim.o.columns = 180
local diag = require 'bufferline.diagnostics'
local ns = vim.api.nvim_create_namespace 'perf-test'
local buffers = {}
for b = 1, 20 do
  local buf = vim.api.nvim_create_buf(true, false)
  buffers[#buffers + 1] = buf
  vim.api.nvim_buf_set_name(buf, '/tmp/performance-buffer-' .. b .. '.txt')
  local lines = {}
  local ds = {}
  for i = 1, 100 do
    lines[i] = 'test'
    ds[i] = { lnum = i - 1, col = 0, message = 'fixture', severity = i % 2 + 1 }
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.diagnostic.set(ns, buf, ds, { virtual_text = false, signs = false, underline = false })
end
local get = vim.diagnostic.get
local calls = 0
vim.diagnostic.get = function(...)
  calls = calls + 1
  return get(...)
end
local function bench()
  calls = 0
  local start = vim.uv.hrtime()
  for i = 1, 100 do
    vim.api.nvim_eval_statusline(vim.o.tabline, { use_tabline = true })
  end
  return { ms = (vim.uv.hrtime() - start) / 1e6, scans = calls }
end
local after = bench()
assert(after.scans <= 1, 'Unchanged diagnostics must not be rescanned per render')
local opts = { diagnostics = 'nvim_lsp' }
assert(diag.get(opts)[buffers[1]].count == 100)
vim.diagnostic.set(ns, buffers[1], { { lnum = 0, col = 0, message = 'changed', severity = 1 } })
assert(diag.get(opts)[buffers[1]].count == 1)
vim.diagnostic.enable(false, { bufnr = buffers[1] })
assert(diag.get(opts)[buffers[1]].count == 0, 'disabled counts stale')
vim.diagnostic.enable(true, { bufnr = buffers[1] })
assert(diag.get(opts)[buffers[1]].count == 1, 'enabled counts stale')
vim.diagnostic.reset(ns, buffers[1])
assert(diag.get(opts)[buffers[1]].count == 0)
vim.diagnostic.get = get
print 'Bufferline diagnostic cache: render reuse, updates, enable/disable and reset passed'
vim.cmd 'qa!'
