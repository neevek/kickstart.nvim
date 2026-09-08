vim.opt.rtp:prepend(vim.fn.getcwd())
local navigation = require 'custom.lsp_navigation'
local pending, timers, displayed = {}, {}, 0
local jumps = {}
local sequence, outstanding, peak = 0, 0, 0
local cancelled = {}
local supports_implementation = true
local client = { name = 'clangd', offset_encoding = 'utf-16', id = 1 }
function client:stop() end

function client:request(method, params, callback)
  sequence = sequence + 1
  pending[sequence] = { method = method, params = params, callback = callback }
  outstanding = outstanding + 1
  peak = math.max(peak, outstanding)
  return true, sequence
end

function client:cancel_request(id)
  cancelled[id] = true
  if pending[id] then
    outstanding = outstanding - 1
  end
  pending[id] = nil
end

local function respond(id, result, err)
  local request = assert(pending[id])
  pending[id] = nil
  outstanding = outstanding - 1
  request.callback(err, result)
  vim.wait(10)
end

local function location(file, line)
  return {
    uri = vim.uri_from_fname(vim.g.test_directory .. '/' .. file),
    range = {
      start = { line = line or 0, character = 0 },
      ['end'] = { line = line or 0, character = 1 },
    },
  }
end

vim.lsp.get_clients = function(opts)
  if opts and opts.method == 'textDocument/implementation' and not supports_implementation then
    return {}
  end
  return { client }
end
vim.lsp.buf_attach_client = function()
  return true
end
vim.lsp.util.show_document = function(loc, encoding, opts)
  jumps[#jumps + 1] = loc
  assert(encoding == 'utf-16' and opts.focus and opts.reuse_win)
  return true
end
vim.g.test_directory = vim.fn.tempname()
vim.fn.mkdir(vim.g.test_directory, 'p')
for i = 1, 10 do
  vim.fn.writefile({ '// header' }, vim.g.test_directory .. '/override' .. i .. '.h')
end
vim.fn.writefile({ '// header' }, vim.g.test_directory .. '/unindexed.h')
vim.defer_fn = function(callback, delay)
  timers[#timers + 1] = { callback = callback, delay = delay }
end
package.loaded['telescope.builtin'] = {
  quickfix = function()
    displayed = displayed + 1
  end,
}

navigation.implementations()
assert(sequence == 1 and displayed == 0, 'navigation must return before the server responds')
local declarations = {}
for i = 1, 10 do
  declarations[i] = location('override' .. i .. '.h')
end
respond(1, declarations)
assert(outstanding == 4, 'definition requests must have bounded concurrency')
while next(pending) do
  local id, request = next(pending)
  assert(request.method == 'textDocument/definition')
  respond(id, { location('implementation.cpp', id) })
end
assert(peak <= 4 and displayed == 1, 'all results should be shown once')
assert(#vim.fn.getqflist() == 10)
for i = 1, 10 do
  assert(vim.fn.bufnr(vim.g.test_directory .. '/override' .. i .. '.h') == -1, 'temporary header buffers must be cleaned up')
end
for _, item in ipairs(vim.fn.getqflist()) do
  assert(vim.bo[item.bufnr].buflisted, 'selected implementation must be visible in bufferline')
  assert(not vim.api.nvim_buf_is_loaded(item.bufnr), 'navigation must not preload source buffers')
end

timers = {}
navigation.implementations()
local old_id = sequence
local old_callback = pending[old_id].callback
navigation.implementations()
assert(cancelled[old_id], 'a newer invocation must cancel the old request')
old_callback(nil, { location 'stale.cpp' })
assert(displayed == 1, 'late cancelled responses must not open a picker')
respond(sequence, { location 'inline.cpp' })
assert(displayed == 1 and #jumps == 1 and jumps[1].uri:match 'inline.cpp$', 'single implementations must jump directly')

timers = {}
navigation.implementations()
respond(sequence, { location 'unindexed.h' })
local id = sequence
for _, timer in ipairs(timers) do
  if timer.delay == 3000 then
    timer.callback()
  end
end
vim.wait(10)
assert(cancelled[id] and displayed == 1 and #jumps == 2, 'timed-out definitions should fall back to declarations')
assert(jumps[2].uri:match 'unindexed.h$')

timers = {}
navigation.implementations()
local call = pending[sequence].params
respond(sequence, {})
assert(pending[sequence].method == 'textDocument/definition', 'ordinary methods must fall back to their definition')
assert(vim.deep_equal(pending[sequence].params, call), 'fallback must query the original call site')
local definition = location('ApolloSettings.cpp', 864)
respond(sequence, { targetUri = definition.uri, targetSelectionRange = definition.range, targetRange = definition.range })
assert(displayed == 1 and #jumps == 3, 'single definitions must jump without opening a picker')
assert(jumps[3].range.start.line == 864, 'fallback must preserve the exact overload location')

navigation.implementations()
respond(sequence, {})
old_id = sequence
old_callback = pending[old_id].callback
navigation.implementations()
assert(cancelled[old_id], 'superseded fallback requests must be cancelled')
old_callback(nil, { location 'stale.cpp' })
assert(displayed == 1 and #jumps == 3, 'cancelled fallbacks must neither jump nor open a picker')
respond(sequence, { location 'inline.cpp' })
assert(displayed == 1 and #jumps == 4)

supports_implementation = false
navigation.implementations()
assert(pending[sequence].method == 'textDocument/definition', 'definition-only servers must also be navigable')
respond(sequence, { location 'ordinary.cpp' })
assert(displayed == 1 and #jumps == 5)

navigation.implementations()
respond(sequence, { location 'first.cpp', location 'second.cpp' })
assert(displayed == 2 and #jumps == 5 and #vim.fn.getqflist() == 2, 'multiple definitions must still open a picker')

navigation.implementations()
respond(sequence, { location 'ordinary.cpp', location 'ordinary.cpp' })
assert(displayed == 2 and #jumps == 6, 'duplicate locations must not force a picker')

navigation.implementations()
respond(sequence, { location 'ordinary.cpp', location 'unittest/hidden.cpp' })
assert(displayed == 2 and #jumps == 7, 'one visible destination must jump after applying the search policy')

local cwd = vim.fn.getcwd()
vim.fn.mkdir(vim.g.test_directory .. '/unittest', 'p')
vim.cmd.lcd(vim.g.test_directory .. '/unittest')
navigation.implementations()
respond(sequence, { location 'ordinary.cpp', location 'unittest/hidden.cpp' })
assert(displayed == 3 and #jumps == 7, 'test destinations must remain available from unittest directories')
vim.cmd.lcd(cwd)
navigation.cancel()
vim.lsp.get_clients = function()
  return {}
end
vim.fn.delete(vim.g.test_directory, 'rf')
print 'LSP navigation: overrides, definition fallback, concurrency, cancellation, timeout and buffer behavior passed'
