local M = {}

function M.in_unittest(cwd)
  local path = vim.fn.fnamemodify(vim.fs.normalize(cwd or vim.fn.getcwd()), ':p'):gsub('\\', '/')
  return ('/' .. path .. '/'):find('/unittest/', 1, true) ~= nil
end

function M.setup_telescope()
  local pickers = require 'telescope.pickers'
  local new = pickers.new
  -- Telescope accepts a static ignore list, so evaluate the directory at picker creation.
  pickers.new = function(opts, defaults)
    opts, defaults = vim.tbl_extend('force', {}, opts or {}), defaults or {}
    local cwd = opts.cwd or defaults.cwd or vim.fn.getcwd()
    local patterns = opts.file_ignore_patterns or defaults.file_ignore_patterns or require('telescope.config').values.file_ignore_patterns
    opts.file_ignore_patterns = vim.deepcopy(patterns or {})
    if not M.in_unittest(cwd) then
      table.insert(opts.file_ignore_patterns, 'unittest')
    end
    return new(opts, defaults)
  end
end

function M.snacks_config(opts)
  if opts.source == 'explorer' then
    return opts
  end
  opts.filter = opts.filter or {}
  local previous = opts.filter.filter
  local last_cwd, include_tests
  opts.filter.filter = function(item, filter)
    if last_cwd ~= filter.cwd then
      last_cwd, include_tests = filter.cwd, M.in_unittest(filter.cwd)
    end
    local allowed = include_tests or not item.file or not item.file:find('unittest', 1, true)
    return allowed and (not previous or previous(item, filter))
  end
  local cwd = type(opts.filter.cwd) == 'string' and opts.filter.cwd or opts.cwd
  if not M.in_unittest(cwd) then
    opts.exclude = vim.list_extend(vim.deepcopy(opts.exclude or {}), { '*unittest*' })
  end
  return opts
end

return M
