return {
  'sindrets/diffview.nvim',
  commit = '4516612fe98ff56ae0415a259ff6361a89419b0a',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  cmd = { 'DiffviewOpen', 'DiffviewClose', 'DiffviewFileHistory', 'DiffviewToggleFiles', 'DiffviewFocusFiles', 'DiffviewRefresh' },
  keys = {
    { '<leader>gv', '<cmd>DiffviewOpen<cr>', desc = 'Review working changes' },
    { '<leader>gV', '<cmd>DiffviewOpen --cached<cr>', desc = 'Review staged changes' },
    { '<leader>gh', '<cmd>DiffviewFileHistory %<cr>', desc = 'Review current file history' },
    { '<leader>gH', '<cmd>DiffviewFileHistory<cr>', desc = 'Review repository history' },
  },
  config = function()
    require('diffview').setup {
      enhanced_diff_hl = true,
      view = {
        default = { layout = 'diff2_horizontal', winbar_info = true },
        file_history = { layout = 'diff2_horizontal', winbar_info = true },
      },
      file_panel = { win_config = { position = 'left', width = 42 } },
      hooks = {
        diff_buf_read = function(bufnr)
          -- Git revisions are scratch buffers, excluded by the normal FileType hook.
          local bytes = vim.api.nvim_buf_get_offset(bufnr, vim.api.nvim_buf_line_count(bufnr))
          if vim.bo[bufnr].filetype ~= 'bigfile' and bytes <= 1.5 * 1024 * 1024 then
            pcall(vim.treesitter.start, bufnr)
          end
        end,
      },
      keymaps = {
        view = { { 'n', 'q', '<cmd>DiffviewClose<cr>', { desc = 'Close entire diff review' } } },
        file_panel = { { 'n', 'q', '<cmd>DiffviewClose<cr>', { desc = 'Close entire diff review' } } },
        file_history_panel = { { 'n', 'q', '<cmd>DiffviewClose<cr>', { desc = 'Close entire diff review' } } },
      },
    }
    local function colors()
      vim.api.nvim_set_hl(0, 'DiffviewDiffAdd', { bg = '#173d29' })
      -- Enhanced highlighting maps removed content on the old side to this group.
      vim.api.nvim_set_hl(0, 'DiffviewDiffAddAsDelete', { bg = '#48232b' })
      vim.api.nvim_set_hl(0, 'DiffviewDiffChange', { bg = '#252b3d' })
      vim.api.nvim_set_hl(0, 'DiffviewDiffText', { bg = '#344d70' })
      vim.api.nvim_set_hl(0, 'DiffviewDiffDeleteDim', { fg = '#202024', bg = '#080809' })
      vim.api.nvim_set_hl(0, 'DiffviewDiffDelete', { link = 'DiffviewDiffDeleteDim' })
    end
    colors()
    vim.api.nvim_create_autocmd('ColorScheme', {
      group = vim.api.nvim_create_augroup('custom-diffview-colors', { clear = true }),
      callback = colors,
    })
  end,
}
