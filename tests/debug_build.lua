vim.opt.rtp:prepend(vim.fn.getcwd())
local m = require 'custom.debug_build'
local root = vim.fn.tempname() .. ' space'
vim.fn.mkdir(root .. '/.vscode', 'p')
local marker = root .. '/result'
vim.fn.mkdir(root .. '/project', 'p')
vim.fn.writefile({ '#!/bin/sh', 'printf wrapper > wrapper-result' }, root .. '/project/gradlew')
vim.fn.setfperm(root .. '/project/gradlew', 'rwx------')
local function task(label, code, dep)
  return { label = label, type = 'process', command = 'python3', args = { '-c', code }, dependsOn = dep, options = { cwd = '${workspaceFolder}' } }
end
local tasks = {
  task('first', "from pathlib import Path; Path('result').write_text('first')"),
  task('second', "from pathlib import Path; p=Path('result'); p.write_text(p.read_text()+' second')", 'first'),
  task('fail', 'raise SystemExit(7)'),
  task('must-not-run', "from pathlib import Path; Path('bad').touch()", 'fail'),
  task('slow', 'import time; time.sleep(20)'),
  { label = 'wrapper', type = 'process', command = './gradlew', options = { cwd = '${workspaceFolder}/project' } },
}
vim.fn.writefile({ vim.json.encode { version = '2.0.0', tasks = tasks } }, root .. '/.vscode/tasks.json')
local function run(label)
  local done, ok, err
  local co = coroutine.create(function()
    ok, err = pcall(m.run, label, root)
    done = true
  end)
  assert(coroutine.resume(co))
  assert(
    vim.wait(10000, function()
      return done
    end),
    'build timed out'
  )
  return ok, err
end
local windows = #vim.api.nvim_list_wins()
assert(run 'second')
assert(vim.fn.readfile(marker)[1] == 'first second')
assert(#vim.api.nvim_list_wins() == windows, 'successful build must close its terminal')
assert(run 'wrapper')
assert(vim.fn.readfile(root .. '/project/wrapper-result')[1] == 'wrapper', 'relative executable must resolve against task cwd')
local ok, err = run 'must-not-run'
assert(not ok and tostring(err):find '7')
assert(vim.fn.filereadable(root .. '/bad') == 0)
assert(not pcall(m.plan, 'missing', root))
package.loaded.dap = { listeners = { on_config = {} }, ABORT = {} }
m.setup()
vim.defer_fn(function()
  vim.cmd 'DapBuildCancel'
end, 100)
ok, err = run 'slow'
assert(not ok and tostring(err):find 'cancelled', 'cancelled build must abort launch')
vim.fn.delete(root, 'rf')
print 'Build tasks: sequential dependencies, spaced cwd, failure gating and terminal cleanup passed'
vim.cmd 'qa!'
