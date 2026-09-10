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
  local sources = {}
  local function stop(session)
    if sources[session] then
      sources[session]:stop()
      sources[session] = nil
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
    sources[session] = require('custom.logview').logcat(info.serial, info.pid, { open = false, title = config.android.package })
    vim.schedule(function()
      if sources[session] then
        sources[session]:open()
      end
    end)
  end
  dap.listeners.before.event_terminated['android-logcat'] = stop
  dap.listeners.before.event_exited['android-logcat'] = stop
  dap.listeners.after.disconnect['android-logcat'] = stop
end

return M
