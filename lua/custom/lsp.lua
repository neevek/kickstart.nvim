local M = {}

function M.setup()
  vim.lsp.config('*', { capabilities = require('cmp_nvim_lsp').default_capabilities() })
  local clangd = vim.env.NVIM_CLANGD or (vim.fn.has 'macunix' == 1 and '/usr/bin/clangd' or 'clangd')
  local tidy_enabled = false
  local function configure_clangd()
    vim.lsp.config('clangd', {
      cmd = { clangd, '--background-index', '--background-index-priority=low', '-j=4', '--log=error', '--clang-tidy=' .. tostring(tidy_enabled) },
    })
  end
  configure_clangd()
  vim.api.nvim_create_user_command('ClangdTidyToggle', function()
    tidy_enabled = not tidy_enabled
    configure_clangd()
    vim.cmd.LspRestart 'clangd'
    vim.notify('clang-tidy ' .. (tidy_enabled and 'enabled' or 'disabled'))
  end, { desc = 'Toggle clang-tidy analysis and restart clangd' })
  require('custom.arkts').setup()
  require('custom.apollo').setup()
  vim.lsp.config('lua_ls', {
    settings = { Lua = { diagnostics = { globals = { 'vim', 'Snacks' } }, workspace = { checkThirdParty = false } } },
  })
  vim.lsp.config('pyright', {
    settings = { python = { analysis = { diagnosticMode = 'openFilesOnly', autoSearchPaths = true } } },
  })

  local java_home = vim.env.JDTLS_JAVA_HOME
  if not java_home and vim.fn.has 'macunix' == 1 then
    local bundled = '/Applications/Android Studio.app/Contents/jbr/Contents/Home'
    if vim.fn.executable(bundled .. '/bin/java') == 1 then
      java_home = bundled
    end
  end
  vim.lsp.config('jdtls', {
    settings = { java = {} },
    before_init = function(_, config)
      if config.root_dir and config.root_dir:match '/sdk%-java$' then
        local gradle_java = vim.fn.expand '~/.sdkman/candidates/java/17.0.12-librca'
        config.settings.java['import'] = {
          gradle = {
            wrapper = { enabled = false },
            version = '7.5.1',
            java = { home = gradle_java },
          },
        }
      end
    end,
    cmd_env = java_home and { JAVA_HOME = java_home } or nil,
    root_markers = { { 'settings.gradle', 'settings.gradle.kts', 'mvnw', 'gradlew' }, { 'pom.xml', 'build.gradle', 'build.gradle.kts' }, '.git' },
    cmd = function(dispatchers, config)
      local root = config.root_dir or vim.fn.getcwd()
      local workspace = vim.fn.stdpath 'cache' .. '/jdtls/' .. vim.fn.sha256(root):sub(1, 16)
      return vim.lsp.rpc.start({ 'jdtls', '-data', workspace }, dispatchers, { cwd = config.cmd_cwd, env = config.cmd_env })
    end,
  })

  vim.api.nvim_create_user_command('LspNavigationCancel', function()
    local navigation = package.loaded['custom.lsp_navigation']
    if navigation then
      navigation.cancel()
    end
  end, {})
  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('custom-lsp-diagnostics', { clear = true }),
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client and client.name == 'clangd' then
        for _, pull in ipairs { false, true } do
          vim.diagnostic.config({
            virtual_text = { prefix = '●', spacing = 2, severity = { min = vim.diagnostic.severity.ERROR } },
            virtual_lines = false,
          }, vim.lsp.diagnostic.get_namespace(client.id, pull))
        end
      end
      if client and client.name == 'rust-analyzer' then
        for _, pull in ipairs { false, true } do
          vim.diagnostic.config({ virtual_lines = true }, vim.lsp.diagnostic.get_namespace(client.id, pull))
        end
      end
    end,
  })
end

return M
