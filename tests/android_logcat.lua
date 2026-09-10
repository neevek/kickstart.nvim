vim.opt.rtp:prepend(vim.fn.getcwd())
local root = vim.fn.tempname()
vim.fn.mkdir(root, 'p')
local adb = root .. '/adb'
vim.fn.writefile({
  '#!/usr/bin/env python3',
  'import sys,time',
  "assert sys.argv[1:]==['-s','test-device','logcat','-v','brief','-T','1','--pid=123']",
  "print('I/Test(123): hello from logcat',flush=True)",
  'time.sleep(30)',
}, adb)
vim.fn.setfperm(adb, 'rwx------')
local old_path = vim.env.PATH
vim.env.PATH = root .. ':' .. old_path
local viewer = require 'custom.logview'
local dap = { listeners = { after = { event_initialized = {}, disconnect = {} }, before = { event_terminated = {}, event_exited = {} } } }
package.loaded.dap = dap
package.loaded['dap.repl'] = {
  append = function(text)
    appended = appended .. text
  end,
}
require('custom.android_debug').setup_logcat()
local metadata = root .. '/session.json'
vim.fn.writefile({ vim.json.encode { serial = 'test-device', pid = '123' } }, metadata)
local session = { config = { type = 'android-lldb', _androidSessionFile = metadata, android = {} } }
dap.listeners.after.event_initialized['android-logcat'](session)
assert(
  vim.wait(3000, function()
    return table.concat(viewer.sources[#viewer.sources].lines):find('hello from logcat', 1, true) ~= nil
  end),
  'logcat never reached REPL'
)
dap.listeners.after.disconnect['android-logcat'](session)
local source = viewer.sources[#viewer.sources]
assert(source.closed)
local snapshot = #viewer.sources
vim.wait(200, function()
  return false
end)
assert(#viewer.sources == snapshot, 'output continued after disconnect')
session.config.android.logcat = false
dap.listeners.after.event_initialized['android-logcat'](session)
vim.wait(200, function()
  return false
end)
assert(#viewer.sources == snapshot, 'logcat=false must disable streaming')
vim.env.PATH = old_path
vim.fn.delete(root, 'rf')
print 'Android logcat: PID/device selection, REPL output, detach and opt-out passed'
vim.cmd 'qa!'
