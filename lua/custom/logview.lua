local M = { sources = {} }
local levels = { TRACE = 1, VERBOSE = 1, DEBUG = 2, INFO = 3, WARN = 4, WARNING = 4, ERROR = 5, FATAL = 6 }
local short = { V = 1, D = 2, I = 3, W = 4, E = 5, F = 6 }
local function severity(line)
  local tag = line:match '^([VDIWEF])/' or line:match '%[([VDIWEF])%]'
  if tag then
    return short[tag]
  end
  for word in line:gmatch '%u+' do
    if levels[word] then
      return levels[word]
    end
  end
  return 3
end

local Source = {}
Source.__index = Source

function Source:check_scroll()
  if self.rendering then
    return
  end
  for _, win in ipairs(vim.fn.win_findbuf(self.buf)) do
    local view = vim.api.nvim_win_call(win, vim.fn.winsaveview)
    local previous = self.views[win]
    if previous and (view.topline ~= previous.topline or view.leftcol ~= previous.leftcol) then
      self.follow = vim.fn.line('w$', win) >= vim.api.nvim_buf_line_count(self.buf)
    end
    self.views[win] = view
  end
end

function Source:render(force)
  if self.wiping or not vim.api.nvim_buf_is_valid(self.buf) or self.paused then
    return
  end
  if #vim.fn.win_findbuf(self.buf) == 0 then
    return
  end
  self:check_scroll()
  if not self.follow and not force then
    return
  end
  self.rendering = true
  local rows = {}
  for _, line in ipairs(self.lines) do
    local function matches(pattern, compiled)
      return pattern == '' or (self.regex and compiled:match_str(line) ~= nil) or (not self.regex and line:find(pattern, 1, true) ~= nil)
    end
    if severity(line) >= self.minimum and matches(self.include, self.include_re) and (self.exclude == '' or not matches(self.exclude, self.exclude_re)) then
      rows[#rows + 1] = line
    end
  end
  vim.bo[self.buf].modifiable = true
  vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, rows)
  vim.bo[self.buf].modifiable = false
  for _, win in ipairs(vim.fn.win_findbuf(self.buf)) do
    vim.wo[win].winbar = (' Logs: %s | %s | >=%s | +%s -%s | %s ')
      :format(self.title, self.running and 'capturing' or 'stopped', self.minimum, self.include, self.exclude, self.regex and 'regex' or 'literal')
      :gsub('%%', '%%%%')
    if self.follow then
      vim.api.nvim_win_call(win, function()
        vim.wo.scrolloff = 0
        vim.api.nvim_win_set_cursor(win, { math.max(#rows, 1), 0 })
        vim.cmd 'normal! zb'
      end)
    end
    self.views[win] = vim.api.nvim_win_call(win, vim.fn.winsaveview)
  end
  self.rendering = false
end

function Source:feed(text, stream)
  if self.closed then
    return
  end
  self.file:write(text)
  stream = stream or 'stdout'
  local data = (self.partial[stream] or '') .. text
  local start = 1
  while true do
    local finish = data:find('\n', start, true)
    if not finish then
      break
    end
    self.lines[#self.lines + 1] = data:sub(start, finish - 1):gsub('\r$', '')
    start = finish + 1
  end
  self.partial[stream] = data:sub(start)
  -- Bound pathological newline-free output too; the raw capture remains intact.
  if #self.partial[stream] > 65536 then
    self.lines[#self.lines + 1] = self.partial[stream]:sub(-65536)
    self.partial[stream] = ''
  end
  if #self.lines > self.limit then
    local retained = {}
    for i = #self.lines - self.limit + 1, #self.lines do
      retained[#retained + 1] = self.lines[i]
    end
    self.lines = retained
  end
  if not self.scheduled then
    self.scheduled = true
    vim.defer_fn(function()
      self.scheduled = false
      if not self.closed then
        self.file:flush()
      end
      self:render()
    end, 100)
  end
end

function Source:filter(include, exclude, regex, minimum, quiet)
  local include_re, exclude_re
  if regex then
    local ok, err = pcall(function()
      if include ~= '' then
        include_re = vim.regex(include)
      end
      if exclude ~= '' then
        exclude_re = vim.regex(exclude)
      end
    end)
    if not ok then
      if not quiet then
        vim.notify(tostring(err), vim.log.levels.ERROR)
      end
      return false
    end
  end
  self.include, self.exclude, self.regex, self.minimum = include, exclude, regex, minimum
  self.include_re, self.exclude_re = include_re, exclude_re
  self:render(true)
  return true
end

function Source:live_filter(field)
  local previous = { self.include, self.exclude, self.regex, self.minimum }
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { self[field] })
  local width = math.max(20, math.min(80, vim.o.columns - 4))
  local title = ' Live ' .. field .. ' regex · Enter keep · Esc cancel '
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    row = 2,
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
    width = width,
    height = 1,
    style = 'minimal',
    border = 'rounded',
    title = title,
  })
  local alive, generation = true, 0
  local function update()
    if not alive or not vim.api.nvim_buf_is_valid(buf) then
      return false
    end
    local value = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ''
    local ok = self:filter(field == 'include' and value or self.include, field == 'exclude' and value or self.exclude, true, self.minimum, true)
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_set_config(win, { title = ok and title or ' Invalid regex — showing last valid results ' })
    end
    return ok
  end
  local function close(accept)
    if accept and not update() then
      return
    end
    alive = false
    if not accept then
      self:filter(unpack(previous))
    end
    vim.cmd 'stopinsert'
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI', 'TextChangedP' }, {
    buffer = buf,
    callback = function()
      generation = generation + 1
      local current = generation
      vim.defer_fn(function()
        if alive and current == generation then
          update()
        end
      end, 60)
    end,
  })
  vim.api.nvim_create_autocmd('BufWipeout', {
    buffer = buf,
    callback = function()
      alive = false
    end,
  })
  vim.keymap.set({ 'i', 'n' }, '<CR>', function()
    close(true)
  end, { buffer = buf })
  vim.keymap.set({ 'i', 'n' }, '<Esc>', function()
    close(false)
  end, { buffer = buf })
  vim.keymap.set({ 'i', 'n' }, '<C-c>', function()
    close(false)
  end, { buffer = buf })
  vim.api.nvim_win_set_cursor(win, { 1, #self[field] })
  vim.cmd 'startinsert!'
  return buf, win
end

function Source:clear()
  self.lines, self.partial, self.views = {}, {}, {}
  self.follow, self.paused = true, false
  self:render(true)
end

function Source:stop()
  if self.closed then
    return
  end
  self.running = false
  if self.job then
    vim.fn.jobstop(self.job)
    self.job = nil
  end
  for stream, text in pairs(self.partial) do
    if text ~= '' then
      self:feed('\n', stream)
    end
  end
  self.file:flush()
  self.file:close()
  self.closed = true
  self:render()
end

function Source:open()
  local wins = vim.fn.win_findbuf(self.buf)
  if #wins > 0 then
    vim.api.nvim_set_current_win(wins[1])
    return
  end
  vim.cmd 'botright 14new'
  vim.api.nvim_win_set_buf(0, self.buf)
  vim.wo.wrap = false
  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.signcolumn = 'no'
  self:render()
end

function M.new(title, opts)
  opts = opts or {}
  local dir = vim.fn.stdpath 'state' .. '/logview'
  vim.fn.mkdir(dir, 'p')
  local path = dir .. '/' .. os.date '%Y%m%d-%H%M%S' .. '-' .. vim.fn.getpid() .. '-' .. (#M.sources + 1) .. '.log'
  local source = setmetatable({
    title = title,
    path = path,
    file = assert(io.open(path, 'ab')),
    lines = {},
    partial = {},
    limit = opts.limit or 50000,
    views = {},
    include = '',
    exclude = '',
    regex = false,
    minimum = 1,
    running = true,
    follow = true,
    paused = false,
    buf = vim.api.nvim_create_buf(false, true),
  }, Source)
  M.sources[#M.sources + 1] = source
  vim.api.nvim_buf_set_name(source.buf, 'Logs: ' .. title .. ' [' .. #M.sources .. ']')
  vim.bo[source.buf].bufhidden = 'hide'
  vim.bo[source.buf].filetype = 'logview'
  vim.bo[source.buf].modifiable = false
  local function map(key, fn, desc)
    vim.keymap.set('n', key, fn, { buffer = source.buf, desc = desc })
  end
  local function prompt(field)
    source:live_filter(field)
  end
  map('f', function()
    prompt 'include'
  end, 'Include filter')
  map('e', function()
    prompt 'exclude'
  end, 'Exclude filter')
  map('r', function()
    source:filter(source.include, source.exclude, not source.regex, source.minimum)
  end, 'Toggle regex')
  map('s', function()
    vim.ui.select({ 'ALL', 'DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL' }, { prompt = 'Minimum severity' }, function(v)
      if v then
        source:filter(source.include, source.exclude, source.regex, levels[v] or 1)
      end
    end)
  end, 'Severity filter')
  map('p', function()
    source.paused = not source.paused
    source:render()
    vim.notify(source.paused and 'Log display paused; capture continues' or 'Log display resumed')
  end, 'Pause display')
  map('G', function()
    source.views = {}
    source.follow = true
    source.paused = false
    source:render()
  end, 'Follow latest logs')
  map('q', function()
    vim.cmd(#vim.api.nvim_tabpage_list_wins(0) > 1 and 'close' or 'enew')
  end, 'Hide logs; keep capturing')
  map('x', function()
    source:stop()
  end, 'Stop capture')
  map('C', function()
    source:clear()
  end, 'Clear displayed log history')
  map('o', function()
    vim.cmd('split ' .. vim.fn.fnameescape(source.path))
  end, 'Open complete capture')
  map('?', function()
    vim.notify 'f include | e exclude | r regex | s severity | p pause | G follow | C clear | x stop | o full capture | q hide'
  end, 'Log viewer help')
  vim.api.nvim_create_autocmd('WinScrolled', {
    callback = function()
      if source.wiping then
        return true
      end
      local following = source.follow
      source:check_scroll()
      if source.follow and not following then
        source:render()
      end
    end,
  })
  vim.api.nvim_create_autocmd('BufWipeout', {
    buffer = source.buf,
    callback = function()
      source.wiping = true
      source:stop()
      source.lines, source.partial = {}, {}
    end,
  })
  if opts.open ~= false then
    source:open()
  end
  return source
end

function M.command(command, opts)
  opts = opts or {}
  local source = M.new(opts.title or (type(command) == 'string' and command or table.concat(command, ' ')), opts)
  local ok, job = pcall(vim.fn.jobstart, command, {
    cwd = opts.cwd,
    on_stdout = function(_, data)
      source:feed(table.concat(data, '\n'), 'stdout')
    end,
    on_stderr = function(_, data)
      source:feed(table.concat(data, '\n'), 'stderr')
    end,
    on_exit = function(_, code)
      source.job = nil
      source:feed(('\n[capture exited: %d]\n'):format(code))
      source:stop()
    end,
  })
  if ok and job > 0 then
    source.job = job
  else
    source:feed('Could not start log command: ' .. tostring(job) .. '\n')
    source:stop()
    vim.notify('Could not start log command', vim.log.levels.ERROR)
  end
  return source
end

function M.logcat(serial, pid, opts)
  local cmd = { 'adb', '-s', serial, 'logcat', '-v', 'brief', '-T', '1' }
  if pid then
    cmd[#cmd + 1] = '--pid=' .. pid
  end
  opts = vim.tbl_extend('force', { title = 'Android ' .. serial .. (pid and (' PID ' .. pid) or '') }, opts or {})
  return M.command(cmd, opts)
end

function M.android(package)
  vim.system({ 'adb', 'devices' }, { text = true }, function(result)
    vim.schedule(function()
      local devices = {}
      for serial in (result.stdout or ''):gmatch '([^%s]+)%s+device[%s\n]' do
        devices[#devices + 1] = serial
      end
      local function select(serial)
        if not serial then
          return
        end
        if not package or package == '' then
          M.logcat(serial)
          return
        end
        if not package:match '^[%w_.:]+$' then
          vim.notify('Invalid package/process name', vim.log.levels.ERROR)
          return
        end
        vim.system({ 'adb', '-s', serial, 'shell', 'pidof', package }, { text = true }, function(p)
          vim.schedule(function()
            local pid = vim.trim(p.stdout or '')
            if not pid:match '^%d+$' then
              vim.notify('Open the app first: ' .. package, vim.log.levels.ERROR)
              return
            end
            M.logcat(serial, pid, { title = package })
          end)
        end)
      end
      if #devices == 1 then
        select(devices[1])
      elseif #devices > 1 then
        vim.ui.select(devices, { prompt = 'Android device' }, select)
      else
        vim.notify('No authorized Android device found', vim.log.levels.ERROR)
      end
    end)
  end)
end

function M.clear_current()
  local buf = vim.api.nvim_get_current_buf()
  for _, source in ipairs(M.sources) do
    if source.buf == buf then
      source:clear()
      return
    end
  end
  vim.notify('Focus a log viewer window before clearing its history', vim.log.levels.INFO)
end

function M.open()
  local choices = { 'Android logcat', 'Run command', 'Follow file' }
  for _, source in ipairs(M.sources) do
    if vim.api.nvim_buf_is_valid(source.buf) then
      choices[#choices + 1] = source
    end
  end
  vim.ui.select(choices, {
    prompt = 'Logs',
    format_item = function(v)
      return type(v) == 'table' and v.title or v
    end,
  }, function(choice)
    if type(choice) == 'table' then
      choice:open()
    elseif choice == 'Android logcat' then
      vim.ui.input({ prompt = 'Package/process (empty = all device logs): ' }, function(v)
        if v ~= nil then
          M.android(v)
        end
      end)
    elseif choice == 'Run command' then
      vim.ui.input({ prompt = 'Command: ' }, function(v)
        if v and v ~= '' then
          M.command(v)
        end
      end)
    elseif choice == 'Follow file' then
      vim.ui.input({ prompt = 'Log file: ', completion = 'file' }, function(v)
        if v and v ~= '' then
          M.follow_file(v)
        end
      end)
    end
  end)
end

function M.follow_file(path)
  path = vim.fn.fnamemodify(vim.fn.expand(path), ':p')
  return M.command({ 'python3', vim.fn.stdpath 'config' .. '/scripts/log_follow.py', path }, { title = path })
end

vim.api.nvim_create_autocmd('VimLeavePre', {
  group = vim.api.nvim_create_augroup('custom-logview', { clear = true }),
  callback = function()
    for _, source in ipairs(M.sources) do
      source:stop()
    end
  end,
})
return M
