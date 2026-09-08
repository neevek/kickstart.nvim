vim.o.columns = 160
vim.o.lines = 50
local root = vim.fn.tempname()
vim.fn.mkdir(root .. '/.git', 'p')
for _, path in ipairs {
  'src/keep.cpp',
  'src/also_keep.cpp',
  'src/some_unittest_helper.cpp',
  'unittest/drop.cpp',
  'unittest/nested/test.cpp',
  'sdk-cxx/include/ApolloSDK.cpp',
} do
  vim.fn.mkdir(vim.fs.dirname(root .. '/' .. path), 'p')
  vim.fn.writefile({ 'marker unittest text' }, root .. '/' .. path)
end
vim.fn.writefile({ '/sdk-cxx/include/' }, root .. '/.gitignore')
vim.fn.writefile({ '!/sdk-cxx/include/', '!/sdk-cxx/include/**' }, root .. '/.ignore')
vim.cmd.cd(root)
local cases = {
  { 'telescope', 'find_files', root, 3 },
  { 'telescope', 'find_files', root .. '/unittest', 2 },
  { 'telescope', 'find_files', root .. '/unittest/nested', 1 },
  { 'telescope', 'find_files', root, 3 },
  { 'telescope', 'live_grep', root, 3 },
  { 'telescope', 'live_grep', root .. '/unittest', 2 },
  { 'snacks', 'files', root, 3 },
  { 'snacks', 'files', root .. '/unittest', 2 },
  { 'snacks', 'grep', root, 3 },
  { 'snacks', 'grep', root .. '/unittest', 2 },
}
local results, index = {}, 0
local function next_case()
  index = index + 1
  local c = cases[index]
  if not c then
    local failures = {}
    for _, result in ipairs(results) do
      if result.actual ~= result.expected then
        failures[#failures + 1] = result
      end
    end
    if #failures > 0 then
      print(vim.inspect(failures))
      vim.cmd 'cquit 1'
    else
      print 'Search policy: 10 Telescope/Snacks file and grep scenarios passed, including ignored SDK sources'
      vim.cmd 'qa!'
    end
    return
  end
  local picker
  if c[1] == 'telescope' then
    require('telescope.builtin')[c[2]] { cwd = c[3], previewer = false, default_text = c[2] == 'live_grep' and 'marker' or '' }
    picker = require('telescope.actions.state').get_current_picker(vim.api.nvim_get_current_buf())
  else
    picker = Snacks.picker[c[2]] { cwd = c[3], search = c[2] == 'grep' and 'marker' or '', preview = function() end }
  end
  vim.defer_fn(function()
    local paths = {}
    if c[1] == 'telescope' then
      if picker.manager then
        for entry in picker.manager:iter() do
          paths[#paths + 1] = entry.filename or entry.value
        end
      end
      require('telescope.actions').close(picker.prompt_bufnr)
    else
      for _, item in ipairs(picker:items()) do
        paths[#paths + 1] = item.file
      end
      picker:close()
    end
    results[#results + 1] = { backend = c[1], kind = c[2], cwd = c[3], expected = c[4], actual = #paths, paths = paths }
    vim.defer_fn(next_case, 100)
  end, 1000)
end
vim.defer_fn(next_case, 500)
