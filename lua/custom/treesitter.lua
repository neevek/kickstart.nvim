local M = {}
M.languages = {
  'c',
  'cpp',
  'lua',
  'rust',
  'markdown',
  'markdown_inline',
  'bash',
  'python',
  'json',
  'yaml',
  'toml',
  'java',
  'javascript',
  'typescript',
  'cmake',
  'vim',
  'vimdoc',
}

function M.setup()
  local treesitter = require 'nvim-treesitter'
  treesitter.setup()
  -- Avoid loading installer tooling and rebuilding its parser registry on every launch.
  local installed = {}
  for _, lang in ipairs(treesitter.get_installed 'parsers') do
    installed[lang] = true
  end
  local missing = vim.tbl_filter(function(lang)
    return not installed[lang]
  end, M.languages)
  if #missing > 0 then
    treesitter.install(missing)
  end
  vim.api.nvim_create_autocmd('FileType', {
    group = vim.api.nvim_create_augroup('custom-treesitter', { clear = true }),
    callback = function(args)
      if vim.bo[args.buf].buftype ~= '' or vim.bo[args.buf].filetype == 'bigfile' then
        return
      end
      local ok = pcall(vim.treesitter.start, args.buf)
      if not ok then
        vim.bo[args.buf].syntax = vim.bo[args.buf].filetype
      end
    end,
  })
end

return M
