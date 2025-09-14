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

    { 'echasnovski/mini.icons', version = false },

    {
        'nvim-tree/nvim-tree.lua',
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
                },
                update_focused_file = {
                    enable = true,
                    -- update_cwd = true,
                },
            }
        end,
    },

    {
        'neovim/nvim-lspconfig',
        dependencies = {
            { 'j-hui/fidget.nvim', opts = {} },
            'folke/neodev.nvim',
        },
        config = function()
        end,
    },

    {
        "mason-org/mason-lspconfig.nvim",
        dependencies = {
            "mason-org/mason.nvim",
        },
        config = function()
            require('mason').setup()
            require('mason-lspconfig').setup {
                ensure_installed = { "lua_ls", "clangd" },
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
            dashboard = { enabled = true },
            explorer = { enabled = true },
            indent = { enabled = true },
            input = { enabled = true },
            notifier = {
                enabled = true,
                timeout = 3000,
            },
            picker = { enabled = true },
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
        opts = {
            win = {
                border = 'single'
            },
        }
    },
    {
        -- Adds git related signs to the gutter, as well as utilities for managing changes
        'lewis6991/gitsigns.nvim',
        opts = {
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
        version = "*",
        dependencies = 'nvim-tree/nvim-web-devicons',
        opts = {
            options = {
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
                    fg = "#ff0000",
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
        end,
    },

    {
        -- Set lualine as statusline
        'nvim-lualine/lualine.nvim',
        -- See `:help lualine.txt`
        opts = {
            options = {
                icons_enabled = false,
                theme = 'tokyodark',
                component_separators = '|',
                section_separators = '',
            },
        },
    },

    {
        -- Add indentation guides even on blank lines
        'lukas-reineke/indent-blankline.nvim',
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
    { 'numToStr/Comment.nvim',  opts = {} },

    -- Fuzzy Finder (files, lsp, etc)
    {
        'nvim-telescope/telescope.nvim',
        branch = '0.1.x',
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
                config = function()
                    require("telescope").load_extension "frecency"
                end,
            },

            {
                'nvim-telescope/telescope-live-grep-args.nvim',
                dependencies = { 'nvim-telescope/telescope.nvim' },
                config = function()
                    require("telescope").load_extension("live_grep_args")
                end,
            },
        },
        config = function()
            local telescope = require('telescope')

            telescope.setup {
                defaults = {
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
                        '--sort-files', -- Ensures consistent file ordering
                    },
                },
            }

            -- Load any necessary extensions
            telescope.load_extension('fzf')
            telescope.load_extension('live_grep_args')
            telescope.load_extension('frecency')
        end,
    },

    {
        -- Highlight, edit, and navigate code
        'nvim-treesitter/nvim-treesitter',
        dependencies = {
            'nvim-treesitter/nvim-treesitter-textobjects',
        },
        build = ':TSUpdate',
        config = function()
            require('nvim-treesitter.configs').setup {
                ensure_installed = { "c", "lua", "rust", "cpp" },
                highlight = {
                    enable = true,
                    additional_vim_regex_highlighting = false, -- Disable additional regex highlighting (optional)
                },
            }
        end,
    },

    {
        'akinsho/toggleterm.nvim',
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


    -- {
    --     "mfussenegger/nvim-dap",
    --     dependencies = {
    --         {
    --             "rcarriga/nvim-dap-ui",
    --             "nvim-neotest/nvim-nio",
    --             "jay-babu/mason-nvim-dap.nvim",
    --             "theHamsta/nvim-dap-virtual-text",
    --         }
    --     },
    --     config = function()
    --         require('mason-nvim-dap').setup({
    --             ensure_installed = { 'codelldb' }
    --         })
    --
    --         require("nvim-dap-virtual-text").setup()
    --
    --         local mason_registry = require("mason-registry")
    --         local codelldb = mason_registry.get_package("codelldb")
    --         local extension_path = codelldb:get_install_path() .. "/extension/"
    --         local codelldb_path = extension_path .. "adapter/codelldb"
    --
    --         local dap = require("dap")
    --         dap.adapters.codelldb = {
    --             type = 'server',
    --             port = "${port}",
    --             executable = {
    --                 -- Change this to your path!
    --                 command = codelldb_path,
    --                 args = { "--port", "${port}" },
    --             }
    --         }
    --         dap.configurations.rust = {
    --             {
    --                 name = "Launch file",
    --                 type = "codelldb",
    --                 request = "launch",
    --                 program = function()
    --                     return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
    --                 end,
    --                 cwd = '${workspaceFolder}',
    --                 stopOnEntry = false,
    --             },
    --         }
    --
    --         vim.keymap.set('n', '<F5>', function() require('dap').continue() end)
    --         vim.keymap.set('n', '<Leader>n', function() require('dap').step_over() end)
    --         vim.keymap.set('n', '<Leader>s', function() require('dap').step_into() end)
    --         vim.keymap.set('n', '<Leader>o', function() require('dap').step_out() end)
    --         vim.keymap.set('n', '<Leader>b', function() require('dap').toggle_breakpoint() end)
    --         vim.keymap.set('n', '<Leader>lp',
    --             function() require('dap').set_breakpoint(nil, nil, vim.fn.input('Log point message: ')) end)
    --         vim.keymap.set('n', '<Leader>dr', function() require('dap').repl.open() end)
    --         vim.keymap.set('n', '<Leader>dl', function() require('dap').run_last() end)
    --         vim.keymap.set('n', '<Leader>dd', function() require('dap').continue() end)
    --         vim.keymap.set('n', '<Leader>dt', function() require('dap').terminate() end)
    --         vim.keymap.set({ 'n', 'v' }, '<Leader>dh', function() require('dap.ui.widgets').hover() end)
    --         vim.keymap.set({ 'n', 'v' }, '<Leader>dp', function() require('dap.ui.widgets').preview() end)
    --         vim.keymap.set('n', '<Leader>df', function()
    --             local widgets = require('dap.ui.widgets')
    --             widgets.centered_float(widgets.frames)
    --         end)
    --         vim.keymap.set('n', '<Leader>ds', function()
    --             local widgets = require('dap.ui.widgets')
    --             widgets.centered_float(widgets.scopes)
    --         end)
    --
    --         require("neodev").setup({
    --             library = { plugins = { "nvim-dap-ui" }, types = true },
    --         })
    --     end
    -- },
    --
    -- {
    --     "Weissle/persistent-breakpoints.nvim",
    --     config = function()
    --         local opts = { noremap = true, silent = true }
    --         vim.keymap.set("n", "<Leader>db", function() require('persistent-breakpoints.api').toggle_breakpoint() end,
    --             opts)
    --         require('persistent-breakpoints').setup {
    --             load_breakpoints_event = { "BufReadPost" }
    --         }
    --     end,
    -- },
    --
    -- {
    --     "rcarriga/nvim-dap-ui",
    --     keys = {
    --         {
    --             "<leader>du",
    --             function()
    --                 require("dapui").toggle()
    --             end,
    --             silent = true,
    --         },
    --     },
    --     opts = {
    --         mappings = {
    --             expand = { "<CR>", "<2-LeftMouse>" },
    --             open = "o",
    --             remove = "d",
    --             edit = "e",
    --             repl = "r",
    --             toggle = "t",
    --         },
    --         layouts = {
    --             {
    --                 elements = {
    --                     { id = "console", size = 0.70 },
    --                     { id = "repl",    size = 0.30 },
    --                 },
    --                 size = 0.20,
    --                 position = "bottom",
    --             },
    --             {
    --                 elements = {
    --                     { id = "watches",     size = 0.20 },
    --                     { id = "scopes",      size = 0.20 },
    --                     { id = "stacks",      size = 0.40 },
    --                     { id = "breakpoints", size = 0.20 },
    --                 },
    --                 size = 0.25,
    --                 position = "right",
    --             },
    --         },
    --         controls = {
    --             enabled = true,
    --             element = "repl",
    --         },
    --         floating = {
    --             max_height = 0.9,
    --             max_width = 0.5,
    --             border = vim.g.border_chars,
    --             mappings = {
    --                 close = { "q", "<Esc>" },
    --             },
    --         },
    --     },
    --     config = function(_, opts)
    --         require("dapui").setup(opts)
    --     end,
    -- },


    {
        'mrcjkb/rustaceanvim',
        version = '^6',
        lazy = false,
        dependencies = {
            "nvim-lua/plenary.nvim",
        },
        ft = { 'rust' },
        config = function()
            local capabilities = vim.lsp.protocol.make_client_capabilities()
            capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)

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
                                vim.lsp.inlay_hint.enable(true, { 0 })
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
                virtual_lines = true,
            })
        end
    },

    {
        'nvimdev/dashboard-nvim',
        event = 'VimEnter',
        config = function()
            require('dashboard').setup {
                theme = 'hyper',
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
    -- require 'kickstart.plugins.debug',

    -- NOTE: The import below can automatically add your own plugins, configuration, etc from `lua/custom/plugins/*.lua`
    --    You can use this folder to prevent any conflicts with this init.lua if you're interested in keeping
    --    up-to-date with whatever is in the kickstart repo.
    --    Uncomment the following line and add your plugins to `lua/custom/plugins/*.lua` to get going.
    --
    --    For additional information see: https://github.com/folke/lazy.nvim#-structuring-your-plugins
    -- { import = 'custom.plugins' },
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
            if picker.prompt_title and picker.prompt_title:match(picker_title_pattern) then
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
    create_persistent_picker(require('telescope.builtin').lsp_references, "LSP References")
end

local function persistent_frecency()
    create_persistent_picker(require('telescope').extensions.frecency.frecency, "Frecency")
end

local function persistent_lsp_definitions()
    create_persistent_picker(require('telescope.builtin').lsp_definitions, "LSP Definitions")
end

local function persistent_lsp_implementations()
    create_persistent_picker(require('telescope.builtin').lsp_implementations, "LSP Implementations")
end

-- [[ Configure Telescope ]]
-- See `:help telescope` and `:help telescope.setup()`
require('telescope').setup {
    defaults = {
        mappings = {
            i = {
                ['<C-u>'] = false,
                ['<C-d>'] = false,
                ["<C-j>"] = require('telescope.actions').preview_scrolling_down,
                ["<C-k>"] = require('telescope.actions').preview_scrolling_up,
            },
        },
        -- Configure deterministic sorting for consistent results
        sorting_strategy = "ascending",
        file_sorter = require("telescope.sorters").get_fzy_sorter,
        generic_sorter = require("telescope.sorters").get_fzy_sorter,
        tiebreak = function(current_entry, existing_entry, _)
            -- Break ties deterministically by comparing the ordinal values
            return current_entry.ordinal < existing_entry.ordinal
        end,
    },
}

-- Enable telescope fzf native, if installed
pcall(require('telescope').load_extension, 'fzf')

vim.keymap.set('n', '<leader>fa', persistent_builtin, { desc = 'All Telescope commands' })
vim.keymap.set('n', '<leader>ff', persistent_find_files, { desc = 'File finds' })
-- vim.keymap.set('n', '<leader>fw', require('telescope.builtin').live_grep, { desc = 'Live grep' })
vim.keymap.set('n', '<leader>fr', persistent_lsp_references,
    { desc = 'Lists LSP references for word under the cursor' })
vim.keymap.set('n', '<leader>fo', persistent_frecency, { desc = 'Recent search history' })
vim.keymap.set('n', '<leader>fw', persistent_live_grep,
    { desc = 'Live grep with args' })

-- [[ Configure LSP ]]
--  This function gets run when an LSP connects to a particular buffer.
vim.api.nvim_create_autocmd('LspAttach', {
    desc = 'LSP actions',
    callback = function()
        local nmap = function(keys, func, desc)
            if desc then
                desc = 'LSP: ' .. desc
            end
            vim.keymap.set('n', keys, func, { buffer = bufnr, desc = desc })
        end

        nmap('<leader>lr', vim.lsp.buf.rename, 'LSP rename')
        nmap('gd', persistent_lsp_definitions, '[G]oto [D]efinition')
        nmap('gr', persistent_lsp_references, '[G]oto [R]eferences')
        nmap('gI', persistent_lsp_implementations, '[G]oto [I]mplementation')
        nmap('K', vim.lsp.buf.hover, 'Hover Documentation')
    end
})

local cmp = require 'cmp'
local luasnip = require 'luasnip'
require('luasnip.loaders.from_vscode').lazy_load()
luasnip.config.setup {}

cmp.setup {
    window = {
        completion = cmp.config.window.bordered(),
    },
    snippet = {
        expand = function(args)
            luasnip.lsp_expand(args.body)
        end,
    },
    completion = {
        completeopt = 'menu,menuone,noinsert',
    },
    mapping = cmp.mapping.preset.insert {
        ['<C-n>'] = cmp.mapping.select_next_item(),
        ['<C-p>'] = cmp.mapping.select_prev_item(),
        ['<C-b>'] = cmp.mapping.scroll_docs(-4),
        ['<C-f>'] = cmp.mapping.scroll_docs(4),
        ['<C-Space>'] = cmp.mapping.complete {},
        ['<CR>'] = cmp.mapping.confirm {
            behavior = cmp.ConfirmBehavior.Replace,
            select = true,
        },
        ['<Tab>'] = cmp.mapping(function(fallback)
            if cmp.visible() then
                cmp.select_next_item()
            elseif luasnip.expand_or_locally_jumpable() then
                luasnip.expand_or_jump()
            else
                fallback()
            end
        end, { 'i', 's' }),
        ['<S-Tab>'] = cmp.mapping(function(fallback)
            if cmp.visible() then
                cmp.select_prev_item()
            elseif luasnip.locally_jumpable(-1) then
                luasnip.jump(-1)
            else
                fallback()
            end
        end, { 'i', 's' }),
    },
    sources = {
        { name = 'path' },
        { name = 'nvim_lsp' },
        { name = 'luasnip' },
    },
}

-- Autocommand to close NvimTree on closing the last buffer
vim.api.nvim_create_autocmd("QuitPre", {
    callback = function()
        local invalid_win = {}
        local wins = vim.api.nvim_list_wins()
        for _, w in ipairs(wins) do
            local bufname = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w))
            if bufname:match("NvimTree_") ~= nil then
                table.insert(invalid_win, w)
            end
        end
        if #invalid_win == #wins - 1 then
            -- Close all invalid windows (NvimTree)
            for _, w in ipairs(invalid_win) do vim.api.nvim_win_close(w, true) end
        end
    end,
})

-- Auto load and start Obsession for persistent sessions
vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
        local session_file = vim.fn.getcwd() .. "/.session.vim"
        local cli_files = vim.fn.argv()
        local has_session = vim.fn.filereadable(session_file) == 1

        -- Only load session if no files are specified
        if #cli_files == 0 then
            -- If session exists, source it
            if has_session then
                vim.cmd("source " .. session_file)
                -- run filetype detect on all buffers
                for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                    if vim.api.nvim_buf_is_loaded(buf) then
                        vim.api.nvim_buf_call(buf, function()
                            vim.cmd("filetype detect")
                        end)
                    end
                end
            end

            -- If not already recording with Obsession, start it
            -- NOTE: Obsession automatically keeps .session.vim updated on BufEnter and before exit
            if vim.g.this_obsession == nil then
                vim.cmd("Obsess " .. session_file)
            end

            if has_session then
                vim.cmd("NvimTreeOpen")
                vim.cmd("wincmd p")
            end
        end

        -- Open the last file if provided in the command line arguments
        if #cli_files > 0 then
            local last_file = cli_files[#cli_files]
            vim.cmd("edit " .. vim.fn.fnameescape(last_file))
        end
    end,
})
