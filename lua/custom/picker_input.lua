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
    on_show = function(picker)
      if saved.cursor then
        picker.list:view(saved.cursor, saved.top)
      end
    end,
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
        cursor = picker.list.cursor,
        top = picker.list.top,
      }
    end,
  }
end

function M.grep()
  local root = cwd()
  local saved = grep[root] or {}
  require('telescope').extensions.live_grep_args.live_grep_args {
    cwd = root,
    default_text = saved.text or '',
    selection_strategy = 'row',
    attach_mappings = function(buf, map)
      local picker = require('telescope.actions.state').get_current_picker(buf)
      local restored = false
      picker:register_completion_callback(function()
        if restored then
          return
        end
        restored = true
        if saved.row and picker:_get_prompt() == saved.text then
          picker:set_selection(saved.row)
          if saved.view and vim.api.nvim_win_is_valid(picker.results_win) then
            vim.api.nvim_win_call(picker.results_win, function()
              vim.fn.winrestview(saved.view)
            end)
          end
        end
      end)
      -- Capture before selection/closing destroys the prompt, including an empty query.
      vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI', 'BufLeave', 'BufWipeout' }, {
        buffer = buf,
        callback = function()
          if vim.api.nvim_buf_is_valid(buf) then
            local view
            if picker.results_win and vim.api.nvim_win_is_valid(picker.results_win) then
              view = vim.api.nvim_win_call(picker.results_win, vim.fn.winsaveview)
            end
            grep[root] = { text = picker:_get_prompt(), row = picker:get_selection_row(), view = view }
          end
        end,
      })
      map('n', 'q', require('telescope.actions').close)
      return true
    end,
  }
end

return M
