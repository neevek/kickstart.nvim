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
  require('custom.debug_build').setup()
  local function highlight_signs()
    local colors = {
      DapBreakpoint = '#ff667a',
      DapBreakpointCondition = '#ffcc66',
      DapBreakpointRejected = '#ff9966',
      DapLogPoint = '#73daca',
      DapStopped = '#c3e88d',
    }
    for name, color in pairs(colors) do
      vim.api.nvim_set_hl(0, name, { fg = color, bold = true })
      local sign = vim.fn.sign_getdefined(name)[1]
      if sign then
        sign.texthl = name
        vim.fn.sign_define(name, sign)
      end
    end
  end
  highlight_signs()
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = vim.api.nvim_create_augroup('custom-debug-signs', { clear = true }),
    callback = highlight_signs,
  })
  dap.adapters.lldb = lldb_adapter
  dap.adapters['lldb-dap'] = lldb_adapter
  dap.adapters['android-lldb'] = require('custom.android_debug').adapter(lldb_adapter)
  require('custom.android_debug').setup_logcat()
  local output_sources = {}
  for _, adapter in ipairs { 'lldb', 'lldb-dap' } do
    dap.defaults[adapter].on_output = function(session, body)
      if body.category == 'stdout' or body.category == 'stderr' then
        local source = output_sources[session]
        if not source then
          source = require('custom.logview').new(session.config.name .. ' output', { open = false })
          output_sources[session] = source
          source:open()
        end
        source:feed(body.output or '', body.category)
      elseif body.category ~= 'telemetry' then
        require('dap.repl').append(body.output or '', '$', { newline = false })
      end
    end
  end
  local function close_output(session)
    if output_sources[session] then
      output_sources[session]:stop()
      output_sources[session] = nil
    end
  end
  dap.listeners.after.disconnect['logview-output'] = close_output
  dap.listeners.before.event_terminated['logview-output'] = close_output
  dap.listeners.before.event_exited['logview-output'] = close_output
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
