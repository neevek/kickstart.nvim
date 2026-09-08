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
  treesitter.install(M.languages)
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
