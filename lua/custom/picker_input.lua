local M = {}
local files, grep = {}, {}

local function cwd()
  local path = vim.fn.getcwd()
  return vim.uv.fs_realpath(path) or vim.fs.normalize(path)
end

function M.files()
  local root = cwd()
  local saved = files[root] or {}
  return Snacks.picker.files {
    cwd = root,
    pattern = saved.pattern,
    search = saved.search,
    live = saved.live,
    on_close = function(picker)
      local filter = picker.input.filter
      local text = picker.opts.live and filter.search or filter.pattern
      if picker.input.win.buf and vim.api.nvim_buf_is_valid(picker.input.win.buf) then
        text = picker.input:get()
      end
      files[root] = {
        pattern = picker.opts.live and filter.pattern or text,
        search = picker.opts.live and text or filter.search,
        live = picker.opts.live,
      }
    end,
  }
end

function M.grep()
  local root = cwd()
  require('telescope').extensions.live_grep_args.live_grep_args {
    cwd = root,
    default_text = grep[root] or '',
    attach_mappings = function(buf, map)
      local picker = require('telescope.actions.state').get_current_picker(buf)
      -- Capture before selection/closing destroys the prompt, including an empty query.
      vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI', 'BufLeave', 'BufWipeout' }, {
        buffer = buf,
        callback = function()
          if vim.api.nvim_buf_is_valid(buf) then
            grep[root] = picker:_get_prompt()
          end
        end,
      })
      map('n', 'q', require('telescope.actions').close)
      return true
    end,
  }
end

return M
