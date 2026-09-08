local M = {}

local function lldb_adapter(callback)
  local command = vim.env.NVIM_LLDB_DAP
  if not command and vim.fn.has 'macunix' == 1 then
    local result = vim.system({ 'xcrun', '--find', 'lldb-dap' }, { text = true }):wait(5000)
    if result.code == 0 then
      command = vim.trim(result.stdout)
    end
  end
  command = command or vim.fn.exepath 'lldb-dap'
  if command == '' or vim.fn.executable(command) == 0 then
    vim.notify('Install lldb-dap or set NVIM_LLDB_DAP to its executable path', vim.log.levels.ERROR)
    return
  end
  callback { type = 'executable', command = command, name = 'lldb' }
end

function M.setup()
  local dap = require 'dap'
  local dapui = require 'dapui'
  dap.adapters.lldb = lldb_adapter
  dap.adapters['lldb-dap'] = lldb_adapter
  dap.adapters['android-lldb'] = require('custom.android_debug').adapter(lldb_adapter)
  -- Android LLDB reports a stop for each thread; resuming one resumes the process.
  dap.defaults['android-lldb'].auto_continue_if_many_stopped = false
  local launch = {
    name = 'Launch native executable',
    type = 'lldb',
    request = 'launch',
    program = function()
      local path = vim.fn.input('Executable: ', vim.fn.getcwd() .. '/', 'file')
      if path == '' then
        return dap.ABORT
      end
      path = vim.fn.fnamemodify(vim.fn.expand(path), ':p')
      if vim.fn.executable(path) == 0 then
        vim.notify('Not an executable: ' .. path, vim.log.levels.ERROR)
        return dap.ABORT
      end
      return path
    end,
    cwd = '${workspaceFolder}',
    args = {},
    stopOnEntry = false,
  }
  local attach = {
    name = 'Attach to native process',
    type = 'lldb',
    request = 'attach',
    pid = require('dap.utils').pick_process,
    cwd = '${workspaceFolder}',
  }
  for _, ft in ipairs { 'c', 'cpp', 'objc', 'objcpp', 'rust' } do
    dap.configurations[ft] = dap.configurations[ft] or {}
    vim.list_extend(dap.configurations[ft], { vim.deepcopy(launch), vim.deepcopy(attach) })
  end
  dapui.setup {
    layouts = {
      {
        position = 'right',
        size = 48,
        elements = {
          { id = 'scopes', size = 0.4 },
          { id = 'stacks', size = 0.3 },
          { id = 'watches', size = 0.2 },
          { id = 'breakpoints', size = 0.1 },
        },
      },
      { position = 'bottom', size = 10, elements = { { id = 'repl', size = 1 } } },
    },
  }
  dap.listeners.after.event_initialized['debug-ui'] = function()
    dapui.open()
  end
  dap.listeners.before.event_terminated['debug-ui'] = function()
    dapui.close()
  end
  dap.listeners.before.event_exited['debug-ui'] = function()
    dapui.close()
  end
end

return M
