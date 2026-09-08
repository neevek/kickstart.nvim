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
      for _, key in ipairs { 'serial', 'process' } do
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

return M
