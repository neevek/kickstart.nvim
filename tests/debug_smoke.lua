-- Driven by debug_smoke.py against a real LLDB adapter and temporary C++ program.
vim.o.columns = 180
vim.o.lines = 50
assert(not package.loaded.dap, 'debugger must not load during ordinary startup')
require('lazy').load { plugins = { 'nvim-dap' } }
local dap = require 'dap'
local result = { stops = {} }
local done = false
local function finish()
  if done then
    return
  end
  done = true
  vim.fn.writefile({ vim.json.encode(result) }, vim.env.NVIM_DAP_RESULT)
  vim.schedule(function()
    vim.cmd 'qa!'
  end)
end

dap.listeners.after.event_stopped['smoke'] = function(session, body)
  result.stops[#result.stops + 1] = body.reason
  -- Let the normal DAP handler select the stopped thread before stepping it.
  vim.defer_fn(function()
    session:request('stackTrace', { threadId = body.threadId }, function(err, response)
      if err then
        result.error = err
        finish()
        return
      end
      local frame = response.stackFrames[1]
      if #result.stops == 1 then
        result.frame = { name = frame.name, line = frame.line, path = frame.source.path }
        session:request('evaluate', { expression = 'a + b', frameId = frame.id, context = 'watch' }, function(evalerr, value)
          result.evaluation = value and value.result
          result.evaluate_error = evalerr
          dap.step_over()
        end)
      else
        result.step_line = frame.line
        dap.continue()
      end
    end)
  end, 200)
end
dap.listeners.after.event_exited['smoke'] = function(_, body)
  result.exitCode = body.exitCode
  finish()
end
dap.listeners.after.event_terminated['smoke'] = function()
  vim.defer_fn(finish, 200)
end
vim.defer_fn(function()
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  dap.toggle_breakpoint()
  local configs = dap.providers.configs['dap.launch.json']()
  assert(#configs == 1, 'project launch.json must be discovered automatically')
  dap.run(configs[1])
end, 300)
vim.defer_fn(function()
  if not done then
    result.timeout = true
    dap.terminate()
    finish()
  end
end, 15000)
