local M = {}

function M.setup()
  local server = vim.fn.stdpath 'data' .. '/arkts-lsp/node_modules/.bin/arkts-lsp'
  if vim.fn.executable(server) == 0 then
    return
  end
  vim.filetype.add { extension = { ets = 'arkts' } }
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'arkts',
    callback = function(args)
      vim.bo[args.buf].syntax = 'typescript'
    end,
  })
  vim.lsp.config('arkts', {
    cmd = { server, '--stdio' },
    filetypes = { 'arkts' },
    root_dir = function(buf, on_dir)
      local repo = vim.fs.root(buf, '.git')
      if repo and vim.fn.isdirectory(repo .. '/sdk-ohos') == 1 then
        on_dir(repo .. '/sdk-ohos')
      else
        local root = vim.fs.root(buf, { 'build-profile.json5', 'oh-package.json5' })
        if root then
          on_dir(root)
        end
      end
    end,
  })
  vim.lsp.enable 'arkts'
end

return M
