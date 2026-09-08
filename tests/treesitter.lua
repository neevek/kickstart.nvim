-- Run with the installed config: nvim --headless -n -i NONE '+luafile tests/treesitter.lua' '+qa!'
local ok, err = pcall(function()
  vim.cmd 'enew'
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {
    '# Markdown with injected languages',
    '',
    '```lua',
    'local answer = 42',
    '```',
    '',
    '```bash',
    'echo hello',
    '```',
  })
  vim.bo.filetype = 'markdown'
  local parser = vim.treesitter.get_parser(0)
  parser:parse(true)
  assert(vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()], 'Markdown highlighting must be active')
  local children = parser:children()
  assert(children.lua and children.bash and children.markdown_inline, 'Fenced code and inline Markdown must parse')
  print 'Tree-sitter: Markdown, inline Markdown, Lua and Bash injections passed'
end)
if not ok then
  error(err)
end
