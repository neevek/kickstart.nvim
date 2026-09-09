local M = {}

function M.adapter(lldb_adapter)
  return function(callback, config)
    local android = config.android or {}
    if not android.package or android.package == '' then
      vim.notify('Set android.package in the Android launch.json profile', vim.log.levels.ERROR)
      return
    end
    lldb_adapter(function(adapter)
      local command_file = vim.fn.tempname()
      config.program = command_file .. '.exe'
      config._androidSessionFile = command_file .. '.json'
      config.initCommands = vim.list_extend({
        'platform select remote-android',
        'settings set symbols.load-on-demand true',
        'settings set symbols.enable-lldb-index-cache true',
      }, config.initCommands or {})
      config.attachCommands = { 'command source "' .. command_file:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"' }
      local args = {
        vim.fn.stdpath 'config' .. '/scripts/android_lldb.py',
        '--package',
        android.package,
        '--lldb-dap',
        adapter.command,
        '--command-file',
        command_file,
      }
      -- Android's activity manager launches the app; LLDB then attaches to its PID.
      if config.request == 'launch' then
        args[#args + 1] = '--launch'
        config.request = 'attach'
      end
      for _, key in ipairs { 'serial', 'process', 'activity' } do
        if android[key] then
          vim.list_extend(args, { '--' .. key, android[key] })
        end
      end
      callback {
        type = 'executable',
        command = 'python3',
        args = args,
        options = { initialize_timeout_sec = 60 },
      }
    end)
  end
end

function M.setup_logcat()
  local dap = require 'dap'
  local jobs = {}
  local function stop(session)
    local job = jobs[session]
    jobs[session] = nil
    if job then
      vim.fn.jobstop(job)
    end
  end
  dap.listeners.after.event_initialized['android-logcat'] = function(session)
    local config = session.config
    if config.type ~= 'android-lldb' or (config.android or {}).logcat == false then
      return
    end
    local ok, info = pcall(function()
      return vim.json.decode(table.concat(vim.fn.readfile(config._androidSessionFile), '\n'))
    end)
    if not ok then
      vim.notify('Cannot start logcat: ' .. tostring(info), vim.log.levels.WARN)
      return
    end
    local pending, scheduled = {}, false
    local job = vim.fn.jobstart({ 'adb', '-s', info.serial, 'logcat', '--pid=' .. info.pid, '-v', 'brief', '-T', '1' }, {
      on_stdout = function(_, data)
        pending[#pending + 1] = table.concat(data, '\n')
        if scheduled then
          return
        end
        scheduled = true
        vim.defer_fn(function()
          scheduled = false
          if jobs[session] then
            require('dap.repl').append(table.concat(pending))
          end
          pending = {}
        end, 80)
      end,
      on_stderr = function(_, data)
        local message = vim.trim(table.concat(data, '\n'))
        if message ~= '' then
          vim.notify('logcat: ' .. message, vim.log.levels.WARN)
        end
      end,
    })
    if job > 0 then
      jobs[session] = job
    else
      vim.notify('Could not start adb logcat', vim.log.levels.WARN)
    end
  end
  dap.listeners.before.event_terminated['android-logcat'] = stop
  dap.listeners.before.event_exited['android-logcat'] = stop
  dap.listeners.after.disconnect['android-logcat'] = stop
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = vim.api.nvim_create_augroup('custom-android-logcat', { clear = true }),
    callback = function()
      for session in pairs(jobs) do
        stop(session)
      end
    end,
  })
end

return M
