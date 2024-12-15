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
                    width = 40,
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

    -- NOTE: This is where your plugins related to LSP can be installed.
    --  The configuration is done below. Search for lspconfig to find it below.
    {
        -- LSP Configuration & Plugins
        'neovim/nvim-lspconfig',
        dependencies = {
            -- Automatically install LSPs to stdpath for neovim
            { 'williamboman/mason.nvim', config = true },
            'williamboman/mason-lspconfig.nvim',

            -- Useful status updates for LSP
            -- NOTE: `opts = {}` is the same as calling `require('fidget').setup({})`
            { 'j-hui/fidget.nvim',       opts = {} },

            -- Additional lua configuration, makes nvim stuff amazing!
            'folke/neodev.nvim',
        },
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
        config = true,
        opts = {
            options = {
                separator_style = "tabpages",
                offsets = {
                    {
                        filetype = "NvimTree",
                        text = "File Explorer",
                        highlight = "Directory",
                        separator = true
                    }
                },
            },
        },
    },

    {
        "tiagovla/tokyodark.nvim",
        priority = 1000,
        opts = {
            gamma = 1.00, -- adjust the brightness of the theme
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

            vim.api.nvim_set_hl(0, "Comment", { fg = "#888888" })
            vim.api.nvim_set_hl(0, "@comment", { link = "Comment" })
            vim.api.nvim_set_hl(0, 'TelescopeSelection', { bg = '#666666', fg = '#ffffff' })
            vim.api.nvim_set_hl(0, 'TelescopePreviewLine', { bg = '#666666', fg = '#ffffff' })
            vim.api.nvim_set_hl(0, "IndentBlanklineChar", { fg = "#eeeeee" })
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
        },
    },

    {
        -- Highlight, edit, and navigate code
        'nvim-treesitter/nvim-treesitter',
        dependencies = {
            'nvim-treesitter/nvim-treesitter-textobjects',
        },
        build = ':TSUpdate',
        config = function()
            require("nvim-treesitter.configs").setup {
                ensure_installed = { "c", "lua", "rust" },
                highlight = { enable = true, }
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


    {
        "mfussenegger/nvim-dap",
        dependencies = {
            {
                "rcarriga/nvim-dap-ui",
                "nvim-neotest/nvim-nio",
                "jay-babu/mason-nvim-dap.nvim",
                "theHamsta/nvim-dap-virtual-text",
            }
        },
        config = function()
            require('mason-nvim-dap').setup({
                ensure_installed = { 'codelldb' }
            })

            require("nvim-dap-virtual-text").setup()

            local mason_registry = require("mason-registry")
            local codelldb = mason_registry.get_package("codelldb")
            local extension_path = codelldb:get_install_path() .. "/extension/"
            local codelldb_path = extension_path .. "adapter/codelldb"

            local dap = require("dap")
            dap.adapters.codelldb = {
                type = 'server',
                port = "${port}",
                executable = {
                    -- Change this to your path!
                    command = codelldb_path,
                    args = { "--port", "${port}" },
                }
            }
            dap.configurations.rust = {
                {
                    name = "Launch file",
                    type = "codelldb",
                    request = "launch",
                    program = function()
                        return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
                    end,
                    cwd = '${workspaceFolder}',
                    stopOnEntry = false,
                },
            }

            vim.keymap.set('n', '<F5>', function() require('dap').continue() end)
            vim.keymap.set('n', '<Leader>n', function() require('dap').step_over() end)
            vim.keymap.set('n', '<Leader>s', function() require('dap').step_into() end)
            vim.keymap.set('n', '<Leader>o', function() require('dap').step_out() end)
            vim.keymap.set('n', '<Leader>b', function() require('dap').toggle_breakpoint() end)
            vim.keymap.set('n', '<Leader>lp',
                function() require('dap').set_breakpoint(nil, nil, vim.fn.input('Log point message: ')) end)
            vim.keymap.set('n', '<Leader>dr', function() require('dap').repl.open() end)
            vim.keymap.set('n', '<Leader>dl', function() require('dap').run_last() end)
            vim.keymap.set('n', '<Leader>dd', function() require('dap').continue() end)
            vim.keymap.set('n', '<Leader>dt', function() require('dap').terminate() end)
            vim.keymap.set({ 'n', 'v' }, '<Leader>dh', function() require('dap.ui.widgets').hover() end)
            vim.keymap.set({ 'n', 'v' }, '<Leader>dp', function() require('dap.ui.widgets').preview() end)
            vim.keymap.set('n', '<Leader>df', function()
                local widgets = require('dap.ui.widgets')
                widgets.centered_float(widgets.frames)
            end)
            vim.keymap.set('n', '<Leader>ds', function()
                local widgets = require('dap.ui.widgets')
                widgets.centered_float(widgets.scopes)
            end)

            require("neodev").setup({
                library = { plugins = { "nvim-dap-ui" }, types = true },
            })
        end
    },

    {
        "Weissle/persistent-breakpoints.nvim",
        config = function()
            local opts = { noremap = true, silent = true }
            vim.keymap.set("n", "<Leader>db", function() require('persistent-breakpoints.api').toggle_breakpoint() end,
                opts)
            require('persistent-breakpoints').setup {
                load_breakpoints_event = { "BufReadPost" }
            }
        end,
    },

    {
        "rcarriga/nvim-dap-ui",
        keys = {
            {
                "<leader>du",
                function()
                    require("dapui").toggle()
                end,
                silent = true,
            },
        },
        opts = {
            mappings = {
                expand = { "<CR>", "<2-LeftMouse>" },
                open = "o",
                remove = "d",
                edit = "e",
                repl = "r",
                toggle = "t",
            },
            layouts = {
                {
                    elements = {
                        { id = "console", size = 0.70 },
                        { id = "repl",    size = 0.30 },
                    },
                    size = 0.20,
                    position = "bottom",
                },
                {
                    elements = {
                        { id = "watches",     size = 0.20 },
                        { id = "scopes",      size = 0.20 },
                        { id = "stacks",      size = 0.40 },
                        { id = "breakpoints", size = 0.20 },
                    },
                    size = 0.25,
                    position = "right",
                },
            },
            controls = {
                enabled = true,
                element = "repl",
            },
            floating = {
                max_height = 0.9,
                max_width = 0.5,
                border = vim.g.border_chars,
                mappings = {
                    close = { "q", "<Esc>" },
                },
            },
        },
        config = function(_, opts)
            require("dapui").setup(opts)
        end,
    },


    {
        'mrcjkb/rustaceanvim',
        version = '^4',
        lazy = false,
        dependencies = {
            "nvim-lua/plenary.nvim",
            {
                "lvimuser/lsp-inlayhints.nvim",
                opts = {}
            },
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
                            require("lsp-inlayhints").on_attach(client, bufnr)
                        end
                    }
                }
            end
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
        config = function()
            vim.keymap.set({ "v", "n" }, "<tab>", require("actions-preview").code_actions)
        end,
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
        }
    },


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
vim.o.hlsearch = false

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
vim.keymap.set('n', 'tt', ':bwipeout <CR>', { desc = 'close tab' })
vim.keymap.set('n', '<space>', 'yiw', { desc = 'yank word under cursor' })
vim.keymap.set('n', '<space><space>', 'viw"+p', { desc = 'replace word under cursor' })
vim.keymap.set('n', '<space>r', ':%s/\\<<C-r><C-w>\\>//g<Left><Left>',
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
    },
}

-- Enable telescope fzf native, if installed
pcall(require('telescope').load_extension, 'fzf')

vim.keymap.set('n', '<leader>fa', require('telescope.builtin').builtin, { desc = 'All Telescope commands' })
vim.keymap.set('n', '<leader>ff', require('telescope.builtin').find_files, { desc = 'File finds' })
vim.keymap.set('n', '<leader>fw', require('telescope.builtin').live_grep, { desc = 'Live grep' })

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
        nmap('gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')
        nmap('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
        nmap('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
        nmap('K', vim.lsp.buf.hover, 'Hover Documentation')
    end
})

-- mason-lspconfig requires that these setup functions are called in this order
-- before setting up the servers.
require('mason').setup()
require('mason-lspconfig').setup()
require('lspconfig.ui.windows').default_options.border = 'single'

-- Ensure the servers above are installed
local mason_lspconfig = require 'mason-lspconfig'
mason_lspconfig.setup {
    ensure_installed = { "lua_ls", "rust_analyzer", "clangd" },
}

mason_lspconfig.setup_handlers {
    function(server_name)
        if server_name == "rust_analyzer" then
            -- rust_analyzer will be started by the rustaceanvim plugin, so don't config it here
            -- otherwise there will two rust_analyzer instances running
            return
        end

        -- nvim-cmp supports additional completion capabilities, so broadcast that to servers
        local capabilities = vim.lsp.protocol.make_client_capabilities()
        capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)

        require('lspconfig')[server_name].setup {
            capabilities = capabilities,
        }
    end,
}

-- [[ Configure nvim-cmp ]]
-- See `:help cmp`
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
