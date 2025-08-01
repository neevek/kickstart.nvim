# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Neovim configuration based on kickstart.nvim - a minimal, single-file Neovim configuration designed to help users get started with Neovim customization. The configuration uses lazy.nvim as the plugin manager and follows a modular approach.

## Key Commands

### Installation and Setup
- `nvim` - Start Neovim (first run will automatically install plugins via lazy.nvim)
- `nvim --headless "+Lazy! sync" +qa` - Install/update plugins from command line without opening Neovim

### Development Commands
- `nvim .` - Open Neovim in the current directory
- `:Lazy` - Open the lazy.nvim plugin manager UI
- `:Lazy sync` - Manually sync plugins
- `:checkhealth` - Check Neovim health and configuration status
- `:NvimTreeToggle` - Toggle file explorer
- `:BufferLineCycleNext/Prev` - Navigate between buffers (H/L keys)
- `:Telescope find_files` - Find files (leader + ff)
- `:Telescope live_grep_args` - Search in files (leader + fw)

### Telescope Persistent State
All Telescope pickers now preserve both the last input text and selection position between invocations using telescope's built-in caching. Results are sorted consistently to ensure reliable cursor positioning:

- `<leader>ff` - Find files (preserves last search and cursor position)
- `<leader>fw` - Live grep with arguments (preserves last search and cursor position)
- `<leader>fr` - Find references (preserves last search and cursor position)
- `<leader>fa` - All Telescope commands (preserves last search and cursor position)
- `<leader>fo` - Recent files (preserves last search and cursor position)
- `gd` - Go to definition (preserves last search and cursor position)
- `gr` - Go to references (preserves last search and cursor position)
- `gI` - Go to implementations (preserves last search and cursor position)

**Note**: Results are now consistently ordered by using ripgrep's `--sort-files` flag and telescope's deterministic sorting algorithms, ensuring that the same search query always produces results in the same order. Telescope's built-in caching preserves both input text and cursor/scroll positions between invocations. The global cache_picker setting has been removed to avoid conflicts with individual picker configurations.

### Formatting
- `stylua .` - Format all Lua files in the project (requires stylua to be installed)
- `stylua --check .` - Check if Lua files are properly formatted
- Auto-formatting is enabled by default on save for most file types (can be toggled with `:KickstartFormatToggle`)

## Architecture and Structure

### Core Files
- `init.lua` - Main configuration file containing all plugin configurations and keymaps
- `lua/kickstart/plugins/` - Directory containing modular plugin configurations
- `lua/custom/plugins/` - Directory for user-defined custom plugins (imported in init.lua)

### Plugin Management
- Uses lazy.nvim as the plugin manager
- Plugins are configured directly in init.lua as a list
- Plugin-specific configurations are in separate files under lua/kickstart/plugins/
- Custom plugins can be added in lua/custom/plugins/

### Key Plugin Categories
1. **UI/UX**: tokyodark.nvim (theme), nvim-tree.lua (file explorer), bufferline.nvim (buffer tabs)
2. **LSP/Diagnostics**: nvim-lspconfig, mason.nvim, rustaceanvim
3. **Completion**: nvim-cmp with LuaSnip
4. **Navigation**: telescope.nvim (fuzzy finder), flash.nvim (quick navigation)
5. **Git**: gitsigns.nvim
6. **Utilities**: which-key.nvim (keybinding help), toggleterm.nvim (terminal), dashboard-nvim (startup screen)

### Keymaps (Leader is comma ',')
- `<leader>e` - Toggle file explorer
- `<leader>ff` - Find files (with persistent input)
- `<leader>fw` - Live grep with arguments (with persistent input)
- `<leader>fr` - Find references (with persistent input)
- `<leader>s` - Toggle outline
- `<leader>w` - Save file
- `<leader>q` - Quit
- `H/L` - Navigate between buffers
- `<C-j/k/h/l>` - Navigate between windows
- `gd` - Go to definition (with persistent input)
- `gr` - Go to references (with persistent input)
- `gI` - Go to implementations (with persistent input)
- `K` - Show documentation

## Customization Approach

The configuration follows these patterns:
1. Plugins are declared as a list in init.lua with their configurations
2. Plugin configurations can be inline functions or separate module files
3. Custom plugins should be added to lua/custom/plugins/ and imported in init.lua
4. Keymaps are defined after plugin setup for proper functionality

## Dependencies

- Neovim >= 0.9.0 (latest stable or nightly recommended)
- ripgrep (for telescope search functionality)
- Git (for plugin installation)
- For Rust development: rust-analyzer (automatically managed by Mason)
- For Lua development: lua-language-server (automatically managed by Mason)
- For formatting: stylua (for Lua files)