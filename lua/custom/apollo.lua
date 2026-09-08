local M = {}

function M.setup()
  vim.api.nvim_create_user_command('ApolloLspProfile', function(args)
    local root = vim.fs.root(0, '.git') or vim.fs.root(vim.fn.getcwd(), '.git')
    if not root or vim.fn.isdirectory(root .. '/native/engine/inc') == 0 then
      vim.notify('Open a file in an Apollo checkout first', vim.log.levels.WARN)
      return
    end
    local function select(profile)
      if not profile then
        return
      end
      local platform, arch = profile:match '^(%w+)%-(.+)$'
      if not platform then
        vim.notify('Use a profile such as mac-arm64 or android-arm64', vim.log.levels.WARN)
        return
      end
      local command = { 'python3', vim.fn.stdpath 'config' .. '/scripts/apollo_lsp.py', root, '--platform', platform, '--arch', arch, '--activate-only' }
      vim.system(command, { text = true }, function(result)
        vim.schedule(function()
          if result.code ~= 0 then
            vim.notify(result.stderr, vim.log.levels.ERROR)
            return
          end
          vim.cmd.LspRestart 'clangd'
          vim.notify(result.stdout:gsub('%s+$', ''))
        end)
      end)
    end
    if args.args ~= '' then
      select(args.args)
    else
      local profiles = {}
      for _, path in ipairs(vim.fn.glob(root .. '/.cache/lsp/*/compile_commands.json', false, true)) do
        local name = vim.fs.basename(vim.fs.dirname(path))
        local status_file = vim.fs.dirname(path) .. '/status.json'
        if vim.fn.filereadable(status_file) == 1 then
          local status = vim.json.decode(table.concat(vim.fn.readfile(status_file), '\n'))
          if status.ready then
            profiles[#profiles + 1] = name
          end
        end
      end
      vim.ui.select(profiles, { prompt = 'Shared C/C++ platform' }, select)
    end
  end, { nargs = '?', desc = 'Switch Apollo clangd compilation profile' })
end

return M
