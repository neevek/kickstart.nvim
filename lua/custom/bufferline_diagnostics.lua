local M = {}
local invalidate
local wrapped_handler

function M.setup()
  local diagnostics = require 'bufferline.diagnostics'
  if not invalidate then
    local original = diagnostics.get
    local dirty, cached = true, nil
    invalidate = function()
      dirty = true
    end
    diagnostics.get = function(opts)
      if opts.diagnostics ~= 'nvim_lsp' then
        return original(opts)
      end
      -- Preserve bufferline's insert-mode freeze behavior.
      if vim.api.nvim_get_mode().mode:match '^[iR]' then
        dirty = true
        return original(opts)
      end
      if dirty or not cached then
        cached = original(opts)
        dirty = false
      end
      return cached
    end
    vim.api.nvim_create_autocmd({ 'DiagnosticChanged', 'BufWipeout', 'InsertLeave' }, {
      group = vim.api.nvim_create_augroup('custom-bufferline-diagnostics', { clear = true }),
      callback = invalidate,
    })
  end
  invalidate()
  -- Enable/disable calls show/hide without emitting DiagnosticChanged.
  local handler = vim.diagnostic.handlers.bufferline
  if handler and handler ~= wrapped_handler then
    wrapped_handler = handler
    for _, method in ipairs { 'show', 'hide' } do
      local previous = handler[method]
      handler[method] = function(...)
        invalidate()
        if previous then
          return previous(...)
        end
      end
    end
  end
end

return M
