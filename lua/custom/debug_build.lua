local M = {}
local active_job
local cancelled = false

local function expand(value, root)
  if type(value) == 'table' then
    local result = {}
    for k, v in pairs(value) do
      result[k] = expand(v, root)
    end
    return result
  end
  if type(value) ~= 'string' then
    return value
  end
  return (
    value:gsub('%${([^}]+)}', function(key)
      if key == 'workspaceFolder' then
        return root
      end
      if key:sub(1, 4) == 'env:' then
        return assert(vim.env[key:sub(5)], 'Missing environment variable: ' .. key:sub(5))
      end
      error('Unsupported build task variable: ' .. key)
    end)
  )
end

function M.plan(label, root)
  local path = root .. '/.vscode/tasks.json'
  local data = vim.json.decode(table.concat(vim.fn.readfile(path), '\n'), { luanil = { object = true }, skip_comments = true })
  local tasks, visiting, done, plan = {}, {}, {}, {}
  for _, task in ipairs(data.tasks or {}) do
    assert(not tasks[task.label], 'Duplicate task label: ' .. task.label)
    tasks[task.label] = task
  end
  local platform = vim.fn.has 'win32' == 1 and 'windows' or (vim.fn.has 'macunix' == 1 and 'osx' or 'linux')
  local function visit(name)
    assert(not visiting[name], 'Cyclic build task dependency: ' .. name)
    if done[name] then
      return
    end
    local original = assert(tasks[name], 'Unknown build task: ' .. name)
    local task = vim.tbl_deep_extend('force', vim.deepcopy(original), original[platform] or {})
    visiting[name] = true
    local dependencies = task.dependsOn or {}
    if type(dependencies) == 'string' then
      dependencies = { dependencies }
    end
    for _, dependency in ipairs(dependencies) do
      visit(dependency)
    end
    if task.command then
      assert(task.type == 'process', 'Build tasks must use type=process: ' .. name)
      assert(not task.isBackground, 'Background tasks are unsupported: ' .. name)
      task = expand(task, root)
      task.options = task.options or {}
      local cwd = task.options.cwd or root
      if not (cwd:match '^[/\\]' or cwd:match '^%a:[/\\]') then
        cwd = root .. '/' .. cwd
      end
      assert(vim.fn.isdirectory(cwd) == 1, 'Build directory does not exist: ' .. cwd)
      task.options.cwd = cwd
      -- jobstart resolves executable paths before applying its cwd option.
      if task.command:find '[/\\]' and not (task.command:match '^[/\\]' or task.command:match '^%a:[/\\]') then
        task.command = vim.fs.normalize(cwd .. '/' .. task.command)
      end
      plan[#plan + 1] = task
    else
      assert(#dependencies > 0, 'Task has neither a command nor dependencies: ' .. name)
    end
    visiting[name], done[name] = nil, true
  end
  visit(label)
  return plan
end

function M.run(label, root)
  assert(not active_job, 'A debug build is already running')
  cancelled = false
  local tasks = M.plan(label, root)
  local co = assert(coroutine.running(), 'Build tasks must run in a coroutine')
  for _, task in ipairs(tasks) do
    local original_win = vim.api.nvim_get_current_win()
    vim.cmd 'botright 12new'
    local build_win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_get_current_buf()
    vim.bo[buf].bufhidden = 'hide'
    vim.api.nvim_buf_set_name(buf, 'Debug build: ' .. task.label .. ' [' .. buf .. ']')
    local command = vim.list_extend({ task.command }, task.args or {})
    local job = vim.fn.jobstart(command, {
      term = true,
      cwd = task.options.cwd,
      env = task.options.env,
      on_exit = function(_, code)
        active_job = nil
        vim.schedule(function()
          local ok, err = coroutine.resume(co, code)
          if not ok then
            vim.notify(tostring(err), vim.log.levels.ERROR)
          end
        end)
      end,
    })
    assert(job > 0, 'Could not start build task: ' .. task.label)
    active_job = job
    local code = coroutine.yield()
    assert(not cancelled, 'Debug build cancelled; launch aborted')
    assert(code == 0, ('Build task failed (%s): %s; see its terminal output'):format(code, task.label))
    if vim.api.nvim_win_is_valid(original_win) then
      vim.api.nvim_set_current_win(original_win)
    end
    if vim.api.nvim_win_is_valid(build_win) then
      vim.api.nvim_win_close(build_win, true)
    end
    vim.api.nvim_buf_delete(buf, { force = true })
  end
end

function M.setup()
  local dap = require 'dap'
  dap.listeners.on_config['custom-build'] = function(config)
    if not config.preLaunchTask then
      return config
    end
    local result = vim.deepcopy(config)
    local ok, err = pcall(M.run, config.preLaunchTask, vim.fn.getcwd())
    if not ok then
      vim.notify(tostring(err), vim.log.levels.ERROR)
      result.preLaunchTask = dap.ABORT
    else
      result.preLaunchTask = nil
    end
    return result
  end
  vim.api.nvim_create_user_command('DapBuildCancel', function()
    if active_job then
      cancelled = true
      vim.fn.jobstop(active_job)
    end
  end, { desc = 'Cancel the build and prevent debug launch', force = true })
end

return M
