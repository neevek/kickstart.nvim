vim.g.mapleader = ','
vim.g.maplocalleader = ','

-- [[ Install `lazy.nvim` plugin manager ]]
--    https://github.com/folke/lazy.nvim
--    `:help lazy.nvim.txt` for more info
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system {
        'git',
        'clone',
        '--filter=blob:none',
        'https://github.com/folke/lazy.nvim.git',
        '--branch=stable', -- latest stable release
        lazypath,
    }
end
vim.opt.rtp:prepend(lazypath)

-- [[ Configure plugins ]]
-- NOTE: Here is where you install your plugins.
--  You can configure plugins using the `config` key.
--
--  You can also configure plugins after the setup call,
--    as they will be available in your neovim runtime.
require('lazy').setup({
    -- Detect tabstop and shiftwidth automatically
    'tpope/vim-sleuth',
    'tpope/vim-obsession',

    { 'echasnovski/mini.icons', version = false, lazy = true },

    {
        'nvim-tree/nvim-tree.lua',
        cmd = { 'NvimTreeToggle', 'NvimTreeOpen', 'NvimTreeFocus' },
        config = function()
            local function my_on_attach(bufnr)
                local api = require "nvim-tree.api"

                local function opts(desc)
                    return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
                end

                -- default mappings
                api.config.mappings.default_on_attach(bufnr)

                -- custom mappings
                vim.keymap.set('n', 'v', api.node.open.vertical, opts('Vertical split'))
                vim.keymap.set('n', 'h', api.node.open.horizontal, opts('Horizontal split'))
                vim.keymap.set('n', '?', api.tree.toggle_help, opts('Help'))
            end

            require("nvim-tree").setup {
                on_attach = my_on_attach,
                sort = {
                    sorter = "case_sensitive",
                },
                view = {
                    width = 55,
                },
                renderer = {
                    group_empty = true,
                },
                filters = {
                    dotfiles = true,
                    git_ignored = false,
                },
                update_focused_file = {
                    enable = true,
                    update_root = { enable = true },
                },
            }
        end,
    },

    {
        'neovim/nvim-lspconfig',
        lazy = true,
        dependencies = {
            { 'j-hui/fidget.nvim', opts = {} },
        },
        config = function()
        end,
    },

    {
        "mason-org/mason-lspconfig.nvim",
        event = { 'BufReadPre', 'BufNewFile' },
        cmd = { 'Mason', 'MasonInstall', 'MasonUninstall', 'LspInstall', 'LspUninstall' },
        dependencies = {
            'neovim/nvim-lspconfig',
            'hrsh7th/cmp-nvim-lsp',
            "mason-org/mason.nvim",
        },
        config = function()
            require('mason').setup()
            require('custom.lsp').setup()
            require('mason-lspconfig').setup {
                ensure_installed = { "lua_ls", "clangd", "pyright", "bashls", "cmake", "ts_ls", "jsonls", "jdtls" },
                automatic_enable = {
                    exclude = {
                        "rust_analyzer",
                    }
                },
            }
        end,
    },

    {
        -- Autocompletion
        'hrsh7th/nvim-cmp',
        event = 'InsertEnter',
        config = function() require('custom.completion').setup() end,
        dependencies = {
            -- Snippet Engine & its associated nvim-cmp source
            'L3MON4D3/LuaSnip',
            'saadparwaiz1/cmp_luasnip',

            -- Adds LSP completion capabilities
            'hrsh7th/cmp-nvim-lsp',
            'hrsh7th/cmp-path',

            -- Adds a number of user-friendly snippets
            'rafamadriz/friendly-snippets',
        },
    },

    {
        "folke/snacks.nvim",
        priority = 1000,
        lazy = false,
        ---@type snacks.Config
        opts = {
            bigfile = { enabled = true },
            dashboard = { enabled = false },
            explorer = { enabled = false },
            indent = { enabled = false },
            input = { enabled = true },
            notifier = {
                enabled = true,
                timeout = 3000,
            },
            picker = {
                enabled = true,
                formatters = { file = { truncate = math.huge } },
                config = function(opts) return require('custom.search').snacks_config(opts) end,
                layout = { preset = 'preview_top' },
                layouts = {
                    preview_top = {
                        layout = {
                            box = 'vertical',
                            backdrop = false,
                            width = 0.9,
                            height = 0.9,
                            { win = 'preview', height = 0.55, border = 'rounded', title = '{preview}', title_pos = 'center' },
                            {
                                box = 'vertical',
                                border = 'rounded',
                                title = '{title} {live} {flags}',
                                title_pos = 'center',
                                { win = 'input', height = 1, border = 'bottom' },
                                { win = 'list', border = 'none' },
                            },
                        },
                    },
                },
            },
            quickfile = { enabled = true },
            scope = { enabled = true },
            scroll = { enabled = false },
            statuscolumn = { enabled = true },
            words = { enabled = true },
            styles = {
                notification = {
                    -- wo = { wrap = true } -- Wrap notifications
                }
            }
        },
        keys = {
            -- Top Pickers & Explorer
            { "<leader><space>", function() Snacks.picker.smart() end,                                   desc = "Smart Find Files" },
            { "<leader>,",       function() Snacks.picker.buffers() end,                                 desc = "Buffers" },
            { "<leader>/",       function() Snacks.picker.grep() end,                                    desc = "Grep" },
            { "<leader>:",       function() Snacks.picker.command_history() end,                         desc = "Command History" },
            { "<leader>n",       function() Snacks.picker.notifications() end,                           desc = "Notification History" },
            { "<leader>e",       function() Snacks.explorer() end,                                       desc = "File Explorer" },
            -- find
            { "<leader>fb",      function() Snacks.picker.buffers() end,                                 desc = "Buffers" },
            { "<leader>fc",      function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end, desc = "Find Config File" },
            { "<leader>ff",      function() Snacks.picker.files() end,                                   desc = "Find Files" },
            { "<leader>fg",      function() Snacks.picker.git_files() end,                               desc = "Find Git Files" },
            { "<leader>fp",      function() Snacks.picker.projects() end,                                desc = "Projects" },
            { "<leader>fr",      function() Snacks.picker.recent() end,                                  desc = "Recent" },
            -- git
            { "<leader>gb",      function() Snacks.picker.git_branches() end,                            desc = "Git Branches" },
            { "<leader>gl",      function() Snacks.picker.git_log() end,                                 desc = "Git Log" },
            { "<leader>gL",      function() Snacks.picker.git_log_line() end,                            desc = "Git Log Line" },
            { "<leader>gs",      function() Snacks.picker.git_status() end,                              desc = "Git Status" },
            { "<leader>gS",      function() Snacks.picker.git_stash() end,                               desc = "Git Stash" },
            { "<leader>gd",      function() Snacks.picker.git_diff() end,                                desc = "Git Diff (Hunks)" },
            { "<leader>gf",      function() Snacks.picker.git_log_file() end,                            desc = "Git Log File" },
            -- Grep
            { "<leader>sb",      function() Snacks.picker.lines() end,                                   desc = "Buffer Lines" },
            { "<leader>sB",      function() Snacks.picker.grep_buffers() end,                            desc = "Grep Open Buffers" },
            { "<leader>sg",      function() Snacks.picker.grep() end,                                    desc = "Grep" },
            { "<leader>sw",      function() Snacks.picker.grep_word() end,                               desc = "Visual selection or word", mode = { "n", "x" } },
            -- search
            { '<leader>s"',      function() Snacks.picker.registers() end,                               desc = "Registers" },
            { '<leader>s/',      function() Snacks.picker.search_history() end,                          desc = "Search History" },
            { "<leader>sa",      function() Snacks.picker.autocmds() end,                                desc = "Autocmds" },
            { "<leader>sb",      function() Snacks.picker.lines() end,                                   desc = "Buffer Lines" },
            { "<leader>sc",      function() Snacks.picker.command_history() end,                         desc = "Command History" },
            { "<leader>sC",      function() Snacks.picker.commands() end,                                desc = "Commands" },
            { "<leader>sd",      function() Snacks.picker.diagnostics() end,                             desc = "Diagnostics" },
            { "<leader>sD",      function() Snacks.picker.diagnostics_buffer() end,                      desc = "Buffer Diagnostics" },
            { "<leader>sh",      function() Snacks.picker.help() end,                                    desc = "Help Pages" },
            { "<leader>sH",      function() Snacks.picker.highlights() end,                              desc = "Highlights" },
            { "<leader>si",      function() Snacks.picker.icons() end,                                   desc = "Icons" },
            { "<leader>sj",      function() Snacks.picker.jumps() end,                                   desc = "Jumps" },
            { "<leader>sk",      function() Snacks.picker.keymaps() end,                                 desc = "Keymaps" },
            { "<leader>sl",      function() Snacks.picker.loclist() end,                                 desc = "Location List" },
            { "<leader>sm",      function() Snacks.picker.marks() end,                                   desc = "Marks" },
            { "<leader>sM",      function() Snacks.picker.man() end,                                     desc = "Man Pages" },
            { "<leader>sp",      function() Snacks.picker.lazy() end,                                    desc = "Search for Plugin Spec" },
            { "<leader>sq",      function() Snacks.picker.qflist() end,                                  desc = "Quickfix List" },
            { "<leader>sR",      function() Snacks.picker.resume() end,                                  desc = "Resume" },
            { "<leader>su",      function() Snacks.picker.undo() end,                                    desc = "Undo History" },
            { "<leader>uC",      function() Snacks.picker.colorschemes() end,                            desc = "Colorschemes" },
            -- LSP
            { "gd",              function() Snacks.picker.lsp_definitions() end,                         desc = "Goto Definition" },
            { "gD",              function() Snacks.picker.lsp_declarations() end,                        desc = "Goto Declaration" },
            { "gr",              function() Snacks.picker.lsp_references() end,                          nowait = true,                     desc = "References" },
            { "gI",              function() Snacks.picker.lsp_implementations() end,                     desc = "Goto Implementation" },
            { "gy",              function() Snacks.picker.lsp_type_definitions() end,                    desc = "Goto T[y]pe Definition" },
            { "<leader>ss",      function() Snacks.picker.lsp_symbols() end,                             desc = "LSP Symbols" },
            { "<leader>sS",      function() Snacks.picker.lsp_workspace_symbols() end,                   desc = "LSP Workspace Symbols" },
            -- Other
            { "<leader>z",       function() Snacks.zen() end,                                            desc = "Toggle Zen Mode" },
            { "<leader>Z",       function() Snacks.zen.zoom() end,                                       desc = "Toggle Zoom" },
            { "<leader>.",       function() Snacks.scratch() end,                                        desc = "Toggle Scratch Buffer" },
            { "<leader>S",       function() Snacks.scratch.select() end,                                 desc = "Select Scratch Buffer" },
            { "<leader>n",       function() Snacks.notifier.show_history() end,                          desc = "Notification History" },
            { "<leader>bd",      function() Snacks.bufdelete() end,                                      desc = "Delete Buffer" },
            { "<leader>cR",      function() Snacks.rename.rename_file() end,                             desc = "Rename File" },
            { "<leader>gB",      function() Snacks.gitbrowse() end,                                      desc = "Git Browse",               mode = { "n", "v" } },
            { "<leader>gg",      function() Snacks.lazygit() end,                                        desc = "Lazygit" },
            { "<leader>un",      function() Snacks.notifier.hide() end,                                  desc = "Dismiss All Notifications" },
            { "<c-/>",           function() Snacks.terminal() end,                                       desc = "Toggle Terminal" },
            { "<c-_>",           function() Snacks.terminal() end,                                       desc = "which_key_ignore" },
            { "]]",              function() Snacks.words.jump(vim.v.count1) end,                         desc = "Next Reference",           mode = { "n", "t" } },
            { "[[",              function() Snacks.words.jump(-vim.v.count1) end,                        desc = "Prev Reference",           mode = { "n", "t" } },
            {
                "<leader>N",
                desc = "Neovim News",
                function()
                    Snacks.win({
                        file = vim.api.nvim_get_runtime_file("doc/news.txt", false)[1],
                        width = 0.6,
                        height = 0.6,
                        wo = {
                            spell = false,
                            wrap = false,
                            signcolumn = "yes",
                            statuscolumn = " ",
                            conceallevel = 3,
                        },
                    })
                end,
            }
        },
        init = function()
            vim.api.nvim_create_autocmd("User", {
                pattern = "VeryLazy",
                callback = function()
                    -- Setup some globals for debugging (lazy-loaded)
                    _G.dd = function(...)
                        Snacks.debug.inspect(...)
                    end
                    _G.bt = function()
                        Snacks.debug.backtrace()
                    end
                    vim.print = _G.dd -- Override print to use snacks for `:=` command

                    -- Create some toggle mappings
                    Snacks.toggle.option("spell", { name = "Spelling" }):map("<leader>us")
                    Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
                    Snacks.toggle.option("relativenumber", { name = "Relative Number" }):map("<leader>uL")
                    Snacks.toggle.diagnostics():map("<leader>ud")
                    Snacks.toggle.line_number():map("<leader>ul")
                    Snacks.toggle.option("conceallevel",
                        { off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2 }):map("<leader>uc")
                    Snacks.toggle.treesitter():map("<leader>uT")
                    Snacks.toggle.option("background", { off = "light", on = "dark", name = "Dark Background" }):map(
                        "<leader>ub")
                    Snacks.toggle.inlay_hints():map("<leader>uh")
                    Snacks.toggle.indent():map("<leader>ug")
                    Snacks.toggle.dim():map("<leader>uD")
                end,
            })
        end,
    },

    -- Useful plugin to show you pending keybinds.
    {
        'folke/which-key.nvim',
        event = 'VeryLazy',
        opts = {
            win = {
                border = 'single'
            },
        }
    },
    {
        -- Adds git related signs to the gutter, as well as utilities for managing changes
        'lewis6991/gitsigns.nvim',
        event = { 'BufReadPre', 'BufNewFile' },
        opts = {
            current_line_blame = true,
            -- See `:help gitsigns.txt`
            signs = {
                add = { text = '+' },
                change = { text = '~' },
                delete = { text = '_' },
                topdelete = { text = '‾' },
                changedelete = { text = '~' },
            },
            on_attach = function(bufnr)
                local gs = package.loaded.gitsigns

                local function map(mode, l, r, opts)
                    opts = opts or {}
                    opts.buffer = bufnr
                    vim.keymap.set(mode, l, r, opts)
                end

                -- Navigation
                map({ 'n', 'v' }, ']c', function()
                    if vim.wo.diff then
                        return ']c'
                    end
                    vim.schedule(function()
                        gs.next_hunk()
                    end)
                    return '<Ignore>'
                end, { expr = true, desc = 'Jump to next hunk' })

                map({ 'n', 'v' }, '[c', function()
                    if vim.wo.diff then
                        return '[c'
                    end
                    vim.schedule(function()
                        gs.prev_hunk()
                    end)
                    return '<Ignore>'
                end, { expr = true, desc = 'Jump to previous hunk' })

                -- Actions
                -- normal mode
                map('n', '<leader>hb', function()
                    gs.blame_line { full = false }
                end, { desc = 'git blame line' })
                map('n', '<leader>hd', gs.diffthis, { desc = 'git diff against index' })
                map('n', '<leader>hD', function()
                    gs.diffthis '~'
                end, { desc = 'git diff against last commit' })

                -- Toggles
                map('n', '<leader>tb', gs.toggle_current_line_blame, { desc = 'toggle git blame line' })
                map('n', '<leader>td', gs.toggle_deleted, { desc = 'toggle git show deleted' })
            end,
        },
    },

    {
        'akinsho/bufferline.nvim',
        lazy = false,
        version = "*",
        dependencies = 'nvim-tree/nvim-web-devicons',
        config = function(_, opts)
            require('bufferline').setup(opts)
            require('custom.bufferline_diagnostics').setup()
        end,
        opts = {
            options = {
                always_show_bufferline = true,
                max_name_length = 25,
                tab_size = 20,
                offsets = {
                    {
                        filetype = "NvimTree",
                        text = "File Explorer",
                        highlight = "Directory",
                        separator = true
                    }
                },
                diagnostics = "nvim_lsp",
                diagnostics_indicator = function(_, _, diagnostics_dict, _)
                    local e = diagnostics_dict.error or 0
                    local w = diagnostics_dict.warning or 0
                    -- Bufferline measures this text literally when fitting tabs.
                    -- Embedded statusline highlight codes incorrectly consume width.
                    if e == 0 and w == 0 then
                        return ""
                    elseif e > 0 and w == 0 then
                        return string.format("(%d)", e)
                    elseif e == 0 and w > 0 then
                        return string.format("(%d)", w)
                    end
                    return string.format("(%d|%d)", e, w)
                end,
            },
            highlights = {
                buffer_selected = {
                    fg = "#ffcc00",
                    bold = true,
                },
                indicator_selected = {
                    fg = "#ffcc00",
                    bold = true,
                },
                close_button_selected = {
                    fg = "#ffcc00",
                    bold = true,
                },
            },
        },
    },

    {
        "tiagovla/tokyodark.nvim",
        priority = 1000,
        opts = {
            gamma = 1.0, -- adjust the brightness of the theme
        },
        config = function(_, opts)
            require("tokyodark").setup(opts) -- calling setup is optional
            -- Load Tokyodark colorscheme
            vim.cmd("colorscheme tokyodark")
            -- Apply highlights after loading the colorscheme
            vim.api.nvim_set_hl(0, "Normal", { bg = "#000000", underline = false, bold = true })
            vim.api.nvim_set_hl(0, "NormalNC", { bg = "#000000", underline = false, bold = false })
            vim.api.nvim_set_hl(0, "EndOfBuffer", { bg = "#000000", fg = "#000000", underline = false, bold = false })
            vim.api.nvim_set_hl(0, "NvimTreeNormal", { bg = "#000000", underline = false, bold = false })
            vim.api.nvim_set_hl(0, "TelescopeBorder", { bg = "#000000", underline = false, bold = false })
            vim.api.nvim_set_hl(0, "SignColumn", { bg = "#000000", underline = false, bold = false })
            vim.api.nvim_set_hl(0, "MsgArea", { bg = "#000000", underline = false, bold = false })
            vim.api.nvim_set_hl(0, "CursorLine", { bg = "#121212", underline = false, bold = true })
            vim.api.nvim_set_hl(0, "Cursor", { bg = "#cccccc", underline = false, bold = true })

            vim.api.nvim_set_hl(0, "Comment", { fg = "#808080" })
            vim.api.nvim_set_hl(0, "@comment", { link = "Comment" })
            vim.api.nvim_set_hl(0, 'TelescopeSelection', { bg = '#666666', fg = '#ffffff' })
            vim.api.nvim_set_hl(0, 'TelescopePreviewLine', { bg = '#666666', fg = '#ffffff' })
            vim.api.nvim_set_hl(0, "IndentBlanklineChar", { fg = "#eeeeee" })

            vim.api.nvim_set_hl(0, "LspInlayHint", { fg = "#808080" })

            -- Bufferline diagnostic count colors (red errors, yellow warnings, neutral parens)
            vim.api.nvim_set_hl(0, "BufferlineErrCount", { fg = "#ff5555", bold = true })
            vim.api.nvim_set_hl(0, "BufferlineWarnCount", { fg = "#ffcc00", bold = true })
            vim.api.nvim_set_hl(0, "BufferlineDiagDefault", { fg = "#aaaaaa", bold = true })

            -- Give split borders and inactive panel labels more definition on black.
            local function panel_highlights()
                vim.api.nvim_set_hl(0, "WinSeparator", { fg = "#5c72a6", bg = "#000000" })
                vim.api.nvim_set_hl(0, "StatusLine", { fg = "#e1e9ff", bg = "#35476b" })
                vim.api.nvim_set_hl(0, "StatusLineNC", { fg = "#b5c3e3", bg = "#28344d" })
                vim.api.nvim_set_hl(0, "SnacksPickerDir", { fg = "#929db5" })
                vim.api.nvim_set_hl(0, "SnacksPickerMatch", { fg = "#d5a6ff", bold = true })
                vim.api.nvim_set_hl(0, "TelescopeMatching", { fg = "#d5a6ff", bold = true })
                vim.api.nvim_set_hl(0, "SnacksPickerPathIgnored", { fg = "#929db5" })
                vim.api.nvim_set_hl(0, "SnacksPickerPathHidden", { fg = "#929db5" })
                vim.api.nvim_set_hl(0, "SnacksPickerListCursorLine", { bg = "#303a50" })
                vim.api.nvim_set_hl(0, "NvimTreeCursorLine", { bg = "#283246", fg = "#e1e7f2", bold = true })
            end
            panel_highlights()
            vim.api.nvim_create_autocmd("ColorScheme", {
                group = vim.api.nvim_create_augroup("custom-panel-highlights", { clear = true }),
                callback = panel_highlights,
            })
        end,
    },

    {
        -- Set lualine as statusline
        'nvim-lualine/lualine.nvim',
        event = 'VeryLazy',
        -- See `:help lualine.txt`
        opts = function()
            local theme = vim.deepcopy(require('lualine.themes.tokyodark'))
            for _, section in pairs(theme.inactive) do
                section.fg = '#b5c3e3'
                section.bg = '#28344d'
            end
            return {
                options = {
                    icons_enabled = false,
                    theme = theme,
                    component_separators = '|',
                    section_separators = '',
                },
            }
        end,
    },

    {
        -- Add indentation guides even on blank lines
        'lukas-reineke/indent-blankline.nvim',
        event = { 'BufReadPost', 'BufNewFile' },
        main = "ibl",
        config = function()
            require("ibl").setup({
                exclude = {
                    filetypes = { "dashboard" },
                },
                indent = {
                    char = "┊",
                },
                scope = {
                    show_start = false,
                    show_end = false,
                },
            })
        end
    },

    -- "gc" to comment visual regions/lines
    { 'numToStr/Comment.nvim', event = 'VeryLazy', opts = {} },

    -- Fuzzy Finder (files, lsp, etc)
    {
        'nvim-telescope/telescope.nvim',
        cmd = 'Telescope',
        commit = '40aedd8a68c78a656a10a8d62d80c54af59420fb',
        dependencies = {
            'nvim-lua/plenary.nvim',
            -- Fuzzy Finder Algorithm which requires local dependencies to be built.
            -- Only load if `make` is available. Make sure you have the system
            -- requirements installed.
            {
                'nvim-telescope/telescope-fzf-native.nvim',
                -- NOTE: If you are having trouble with this installation,
                --       refer to the README for telescope-fzf-native for more instructions.
                build = 'make',
                cond = function()
                    return vim.fn.executable 'make' == 1
                end,
            },

            {
                "nvim-telescope/telescope-frecency.nvim",
            },

            {
                'nvim-telescope/telescope-live-grep-args.nvim',
            },
        },
        config = function()
            local telescope = require('telescope')

            telescope.setup {
                defaults = {
                    mappings = {
                        i = {
                            ['<C-u>'] = false,
                            ['<C-d>'] = false,
                            ['<C-j>'] = require('telescope.actions').preview_scrolling_down,
                            ['<C-k>'] = require('telescope.actions').preview_scrolling_up,
                        },
                    },
                    sorting_strategy = 'ascending',
                    path_display = {},
                    layout_strategy = 'vertical',
                    layout_config = {
                        width = 0.9,
                        height = 0.9,
                        vertical = {
                            mirror = false,
                            prompt_position = 'top',
                            preview_height = 0.55,
                            preview_cutoff = 20,
                        },
                    },
                    prompt_prefix = "> ",
                    selection_caret = "> ",
                    vimgrep_arguments = {
                        'rg',
                        '--color=never',
                        '--no-heading',
                        '--with-filename',
                        '--line-number',
                        '--column',
                        '--smart-case',
                    },
                },
                extensions = {
                    frecency = { auto_validate = false },
                },
            }
            require('custom.search').setup_telescope()

            -- Load any necessary extensions
            pcall(telescope.load_extension, 'fzf')
            telescope.load_extension('live_grep_args')
            telescope.load_extension('frecency')
        end,
    },

    {
        -- Highlight, edit, and navigate code
        'nvim-treesitter/nvim-treesitter',
        branch = 'main',
        commit = '5cb0114e6242625db56dd6440e945ed1ece10bc7',
        lazy = false,
        build = ':TSUpdate',
        config = function() require('custom.treesitter').setup() end,
    },

    {
        'akinsho/toggleterm.nvim',
        cmd = { 'ToggleTerm', 'TermExec' },
        version = "*",
        config = true,
        opts = {
            size = function(term)
                if term.direction == "horizontal" then
                    return 20
                elseif term.direction == "vertical" then
                    return vim.o.columns * 0.4
                end
            end,

        },
    },

    {
        "saecki/crates.nvim",
        event = { 'BufReadPost Cargo.toml', 'BufNewFile Cargo.toml' },
        opts = {
            popup = {
                autofocus = true,
                show_version_date = true,
                copy_register = '"',
                style = "minimal",
                border = "rounded",
            }
        }
    },


    {
        'mrcjkb/rustaceanvim',
        version = '^6',
        lazy = false,
        dependencies = {
            "nvim-lua/plenary.nvim",
        },
        ft = { 'rust' },
        config = function()
            vim.g.rustaceanvim = function()
                return {
                    inlay_hints = {
                        highlight = "NonText",
                    },
                    tools = {
                        hover_actions = {
                            auto_focus = true,
                        },
                    },
                    server = {
                        on_attach = function(client, bufnr)
                            if vim.lsp.inlay_hint then
                                vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
                            end
                        end
                    }
                }
            end

            vim.diagnostic.config({
                virtual_text = {
                    prefix = '●',
                    spacing = 2,
                },
                signs = true,
                underline = true,
                update_in_insert = false,
                severity_sort = true,
                virtual_lines = false,
            })


        end
    },

    {
        'nvimdev/dashboard-nvim',
        cmd = 'Dashboard',
        event = function()
            if vim.fn.argc() == 0 and vim.fn.filereadable(vim.fn.getcwd() .. '/.session.vim') == 0 then
                return 'VimEnter'
            end
            return {}
        end,
        config = function()
            require('dashboard').setup {
                theme = 'hyper',
                hide = { tabline = false },
                config = {
                    week_header = {
                        enable = true
                    },
                },
            }
        end,
        dependencies = { { 'nvim-tree/nvim-web-devicons' } }
    },

    {
        'windwp/nvim-autopairs',
        event = "InsertEnter",
        opts = {} -- this is equalent to setup({}) function
    },

    {
        "aznhe21/actions-preview.nvim",
        keys = {
            { "<tab>", function() require("actions-preview").code_actions() end, mode = { "n", "v" } },
        },
        opts = {
            telescope = {
                sorting_strategy = "ascending",
                layout_strategy = "vertical",
                layout_config = {
                    width = 0.8,
                    height = 0.9,
                    prompt_position = "top",
                    mirror = false,
                    preview_cutoff = 20,
                    preview_height = function(_, _, max_lines)
                        return max_lines - 15
                    end,
                },
            },
        },
    },

    {
        "folke/flash.nvim",
        event = "VeryLazy",
        ---@type Flash.Config
        opts = {},
        -- stylua: ignore
        keys = {
            { "s",     mode = { "n", "x", "o" }, function() require("flash").jump() end,              desc = "Flash" },
            { "S",     mode = { "n", "x", "o" }, function() require("flash").treesitter() end,        desc = "Flash Treesitter" },
            { "r",     mode = "o",               function() require("flash").remote() end,            desc = "Remote Flash" },
            { "R",     mode = { "o", "x" },      function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
            { "<c-s>", mode = { "c" },           function() require("flash").toggle() end,            desc = "Toggle Flash Search" },
        },
    },

    {
        "hedyhli/outline.nvim",
        lazy = true,
        cmd = { "Outline", "OutlineOpen" },
        opts = {
            outline_window = {
                width = 55,
                relative_width = false,
            },
            keymaps = {
                close = {},
            }
        },
    },

    { "tikhomirov/vim-glsl" },

    -- NOTE: Next Step on Your Neovim Journey: Add/Configure additional "plugins" for kickstart
    --       These are some example plugins that I've included in the kickstart repository.
    --       Uncomment any of the lines below to enable them.
    require 'kickstart.plugins.autoformat',
    require 'kickstart.plugins.debug',

    -- NOTE: The import below can automatically add your own plugins, configuration, etc from `lua/custom/plugins/*.lua`
    --    You can use this folder to prevent any conflicts with this init.lua if you're interested in keeping
    --    up-to-date with whatever is in the kickstart repo.
    --    Uncomment the following line and add your plugins to `lua/custom/plugins/*.lua` to get going.
    --
    --    For additional information see: https://github.com/folke/lazy.nvim#-structuring-your-plugins
    { import = 'custom.plugins' },
}, {
    ui = {
        border = 'rounded',
    },
    install = {
        missing = true,
        colorscheme = { "tokyodark" },
    },
})


vim.g.indent_blankline_filetype_exclude = { 'dashboard' }

-- [[ Setting options ]]
-- See `:help vim.o`
-- NOTE: You can change these options as you wish!

-- added by neevek
vim.opt.whichwrap = "b,s"
vim.opt.ignorecase = true
vim.opt.cmdheight = 0
-- Restore the viewport as well as the cursor when returning through jump history.
vim.opt.jumpoptions:append("view")

-- Set highlight on search
vim.o.hlsearch = true

-- Make line numbers default
vim.wo.number = true

-- Enable mouse mode
vim.o.mouse = 'a'

-- Sync clipboard between OS and Neovim.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.o.clipboard = 'unnamedplus'

-- Enable break indent
vim.o.breakindent = true

-- Save undo history
vim.o.undofile = true

-- Case-insensitive searching UNLESS \C or capital in search
vim.o.ignorecase = true
vim.o.smartcase = true

-- Keep signcolumn on by default
vim.wo.signcolumn = 'yes'

-- Decrease update time
vim.o.updatetime = 250
vim.o.timeoutlen = 300

-- Set completeopt to have a better completion experience
vim.o.completeopt = 'menuone,noselect'

-- NOTE: You should make sure your terminal supports this
vim.o.termguicolors = true

vim.o.tabstop = 4      -- A TAB character looks like 4 spaces
vim.o.expandtab = true -- Pressing the TAB key will insert spaces instead of a TAB character
vim.o.softtabstop = 4  -- Number of spaces inserted instead of a TAB character
vim.o.shiftwidth = 4   -- Number of spaces inserted when indenting

-- [[ Basic Keymaps ]]

-- Keymaps for better default experience
-- See `:help vim.keymap.set()`
vim.keymap.set('i', 'jk', '<Esc>', { noremap = true, silent = true })
vim.keymap.set('i', 'JK', '<Esc>', { noremap = true, silent = true })
vim.keymap.set('n', 'tt', '<cmd>bn | bd #<CR>', { desc = 'close buffer' })
vim.keymap.set('n', '<space>', 'yiw', { desc = 'yank word under cursor' })
vim.keymap.set('n', '<space><space>', 'viw"+p', { desc = 'replace word under cursor' })
vim.keymap.set('n', '<leader>r', ':%s/\\<<C-r><C-w>\\>//g<Left><Left>',
    { desc = 'replace all occurances of word under cursor' })
vim.keymap.set('n', '<leader>q', ':q<CR>', { desc = 'quit' })
vim.keymap.set('n', '<leader>w', ':w<CR>', { desc = 'write' })
vim.keymap.set('n', '<leader>e', ':NvimTreeToggle<CR>', { desc = 'Toggle NvimTree' })
vim.keymap.set('n', '<C-j>', '<C-w>j', { desc = 'Navigate downwards' })
vim.keymap.set('n', '<C-k>', '<C-w>k', { desc = 'Navigate upwards' })
vim.keymap.set('n', '<C-h>', '<C-w>h', { desc = 'Navigate left' })
vim.keymap.set('n', '<C-l>', '<C-w>l', { desc = 'Navigate right' })
vim.keymap.set('n', 'H', ':BufferLineCyclePrev<CR>')
vim.keymap.set('n', 'L', ':BufferLineCycleNext<CR>')
vim.keymap.set('n', '<leader>ta', ':ToggleTerm<CR>')
vim.keymap.set('t', 'jk', '<C-\\><C-n>')    -- for ToggleTerm to back to normal mode
vim.keymap.set('t', '<ESC>', '<C-\\><C-n>') -- for ToggleTerm to back to normal mode
vim.keymap.set('n', '<leader>ls', ':LspStop<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<leader>s', ':Outline<CR>', { noremap = true, silent = true })

-- [[ Highlight on yank ]]
-- See `:help vim.highlight.on_yank()`
local highlight_group = vim.api.nvim_create_augroup('YankHighlight', { clear = true })
vim.api.nvim_create_autocmd('TextYankPost', {
    callback = function()
        vim.highlight.on_yank()
    end,
    group = highlight_group,
    pattern = '*',
})


-- Function to create persistent telescope pickers using built-in caching
local function create_persistent_picker(picker_func, picker_title_pattern, opts)
    opts = opts or {}
    opts.cwd = opts.cwd or vim.fn.getcwd()

    -- Set up caching options
    opts.cache_picker = {
        num_pickers = 1,
        limit_entries = 1000
    }
    opts.selection_strategy = "row"

    -- Check if we have a cached picker and resume it
    local state = require "telescope.state"
    local cached_pickers = state.get_global_key "cached_pickers"

    if cached_pickers and #cached_pickers > 0 then
        -- Look for a cached picker of the same type by matching prompt title
        for i, picker in ipairs(cached_pickers) do
            if picker.prompt_title and picker.prompt_title:match(picker_title_pattern)
                and picker.cwd == opts.cwd then
                -- Resume the cached picker using internal.resume
                require("telescope.builtin.__internal").resume {
                    cache_index = i,
                    cache_picker = opts.cache_picker
                }
                return
            end
        end
    end

    -- If no cached picker found, create a new one with proper attach_mappings
    opts.attach_mappings = function(prompt_bufnr, map)
        local actions = require "telescope.actions"

        -- Standard close mappings
        map('i', '<C-c>', actions.close)
        map('n', 'q', actions.close)

        -- Standard select mappings
        map('i', '<CR>', actions.select_default)
        map('n', '<CR>', actions.select_default)

        return true
    end

    -- Call the picker function
    picker_func(opts)
end

-- Wrapper functions for telescope pickers with input and selection persistence
local function persistent_find_files()
    create_persistent_picker(require('telescope.builtin').find_files, "Find Files")
end

local function persistent_live_grep()
    create_persistent_picker(require('telescope').extensions.live_grep_args.live_grep_args, "Live Grep")
end

local function persistent_builtin()
    create_persistent_picker(require('telescope.builtin').builtin, "Telescope")
end

local function persistent_lsp_references()
    require('telescope.builtin').lsp_references()
end

local function persistent_frecency()
    create_persistent_picker(require('telescope').extensions.frecency.frecency, "Frecency")
end

local function persistent_lsp_definitions()
    require('telescope.builtin').lsp_definitions()
end

local function persistent_lsp_implementations()
    require('custom.lsp_navigation').implementations()
end

vim.keymap.set('n', '<leader>fa', persistent_builtin, { desc = 'All Telescope commands' })
-- vim.keymap.set('n', '<leader>ff', persistent_find_files, { desc = 'File finds' })
-- vim.keymap.set('n', '<leader>fw', require('telescope.builtin').live_grep, { desc = 'Live grep' })
vim.keymap.set('n', '<leader>fr', persistent_lsp_references,
    { desc = 'Lists LSP references for word under the cursor' })
vim.keymap.set('n', '<leader>fo', persistent_frecency, { desc = 'Recent search history' })
vim.keymap.set('n', '<leader>fw', persistent_live_grep, { desc = 'Live grep with args' })

-- [[ Configure LSP ]]
--  This function gets run when an LSP connects to a particular buffer.
vim.api.nvim_create_autocmd('LspAttach', {
    desc = 'LSP actions',
    callback = function(args)
        local bufnr = args.buf
        local nmap = function(keys, func, desc)
            if desc then
                desc = 'LSP: ' .. desc
            end
            vim.keymap.set('n', keys, func, { buffer = bufnr, desc = desc })
        end

        nmap('<leader>lr', vim.lsp.buf.rename, 'LSP rename')
        nmap('<leader>ld', function()
            vim.diagnostic.open_float({ scope = 'line', border = 'rounded' })
        end, 'Show line diagnostics')
        nmap('gd', persistent_lsp_definitions, '[G]oto [D]efinition')
        nmap('gr', persistent_lsp_references, '[G]oto [R]eferences')
        nmap('gI', persistent_lsp_implementations, '[G]oto [I]mplementation')
        nmap('<leader>li', persistent_lsp_implementations, 'LSP [I]mplementations picker')
        nmap('K', vim.lsp.buf.hover, 'Hover Documentation')
    end
})

-- Progress and notification floats must not keep the editor open after its last file closes.
local function normal_windows(exclude)
    local windows = {}
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if win ~= exclude and vim.api.nvim_win_get_config(win).relative == '' then
            windows[#windows + 1] = win
        end
    end
    return windows
end

vim.api.nvim_create_autocmd('WinClosed', {
    callback = function(args)
        local remaining = normal_windows(tonumber(args.match))
        if #remaining ~= 1 then return end
        local win = remaining[1]
        if vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= 'NvimTree' then return end
        vim.schedule(function()
            if vim.api.nvim_win_is_valid(win) and #normal_windows() == 1
                and vim.bo[vim.api.nvim_win_get_buf(win)].filetype == 'NvimTree' then
                vim.cmd.qall()
            end
        end)
    end,
})

-- Auto load and start Obsession for persistent sessions
vim.api.nvim_create_autocmd("VimEnter", {
    -- Restore outside VimEnter so file reads and filetype detection run normally.
    callback = vim.schedule_wrap(function()
        local session_file = vim.fn.getcwd() .. "/.session.vim"
        local cli_files = vim.fn.argv()
        local has_session = vim.fn.filereadable(session_file) == 1

        -- Only load session if no files are specified
        if #cli_files == 0 then
            -- If session exists, source it
            if has_session then
                vim.cmd("source " .. vim.fn.fnameescape(session_file))
            end

            -- If not already recording with Obsession, start it
            -- NOTE: Obsession automatically keeps .session.vim updated on BufEnter and before exit
            if vim.g.this_obsession == nil then
                vim.cmd("Obsess " .. vim.fn.fnameescape(session_file))
            end

            if has_session then
                vim.cmd("NvimTreeOpen")
                vim.cmd("wincmd p")
            end
        end

        -- Open the last file if provided in the command line arguments
        if #cli_files > 0 then
            local last_file = cli_files[#cli_files]
            if vim.fn.isdirectory(last_file) == 1 then
                require('nvim-tree.api').tree.open({ path = last_file })
            elseif #cli_files > 1 then
                vim.cmd("edit " .. vim.fn.fnameescape(last_file))
            end
        end
    end),
})
