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
- `:Telescope find_files` - Telescope file search (`<leader>ff` uses Snacks)
- `:Telescope live_grep_args` - Search in files (leader + fw)

### Navigation and performance

General Telescope pickers preserve their query and selection through picker caching. LSP definitions, references, and implementations always request fresh results for the current symbol. Do not resume LSP results by picker title alone or add ripgrep file sorting: sorting serializes search.

`gI` / `<leader>li` resolve implementation bodies asynchronously through `lua/custom/lsp_navigation.lua`, with four requests in flight and declaration fallback while indexing. Do not reintroduce synchronous requests, fixed waits, or source-buffer preloading. `:LspNavigationCancel` cancels pending work.

An empty implementation result falls back to definition lookup; non-virtual methods have definitions but no overrides. Both Telescope and Snacks show previews above results. Search policy in `lua/custom/search.lua` excludes paths containing `unittest` unless the effective search directory is inside `unittest/`. Preserve the project-local `.ignore` exception for generated SDK source discovery.

Deduplicate and filter navigation destinations before choosing the UI: one visible destination jumps directly, multiple destinations open the picker. File pickers show complete project-relative paths without abbreviated directory components.

For read-only live checks against project files, launch `nvim --headless -n -R -i NONE` so tests do not collide with swap files from the user's running editor. An E325 swap warning can interrupt a jump before its cursor is positioned.

Restore sessions in a scheduled callback after `VimEnter`. Sourcing a session directly inside that autocmd suppresses lazy file events; `nested=true` alone still left filetypes undetected on Neovim 0.12. Verify direct, restored-session, and NvimTree file opening with `python3 tests/startup_ui.py` after changing startup loading.

Bufferline is essential UI and loads eagerly. Dashboard must keep `hide.tabline=false`: otherwise its delayed restore can reset `showtabline` to 1 after bufferline loads. NvimTree shows Git-ignored files and follows the active buffer; picker search exclusions are a separate policy. Check rendered UI and tree selection in a real terminal, not just plugin-loaded flags in headless mode.

Startup has one owner: automatically show the dashboard only when there are no file arguments and no session to restore. Running dashboard startup alongside session restoration can wipe the same initial buffer twice. `:Dashboard` remains available explicitly.

Telescope is pinned to upstream commit `40aedd8a68c78a656a10a8d62d80c54af59420fb` for the batched cached-finder replay fix. Run `tests/search_policy.lua` with the real config when changing Telescope or picker filtering.

Completion, Telescope, NvimTree, and terminal setup must stay inside their lazy plugin configs. Top-level `require()` calls can defeat lazy loading.

Tree-sitter uses the pinned `main` branch and Neovim 0.12's highlighting API in `lua/custom/treesitter.lua`. The frozen `master` branch registers obsolete single-node directives; Markdown injections crash with `attempt to call method 'range'` on 0.12. Keep Tree-sitter eager as required upstream, and keep the parser CLI installed. Validate Markdown fenced-code parsing with `tests/treesitter.lua` as well as the startup UI tests.

Native debugging is generic and lazy-loaded through `lua/kickstart/plugins/debug.lua` and `lua/custom/debug.lua`. Prefer Xcode's `lldb-dap` on macOS; `NVIM_LLDB_DAP` overrides it. Project profiles live in `.vscode/launch.json`, automatically read by nvim-dap from the current working directory. Do not hardcode Apollo paths into the global debugger or add another launch.json loader. See `DEBUGGING.md`; `python3 tests/debug_smoke.py` verifies real breakpoints, evaluation and stepping.

Apollo platform profiles, refresh commands, dependency prerequisites, and server setup are documented in `LSP_SETUP.md`. `:ApolloLspProfile` switches the shared-code platform. Python and the native compilation databases are configured locally in each checkout.

### Formatting
- `stylua .` - Format all Lua files in the project (requires stylua to be installed)
- `stylua --check .` - Check if Lua files are properly formatted
- Only Rust is formatted on save (toggle with `:KickstartFormatToggle`); other file types are opt-in.

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

- Neovim >= 0.12 (verified with 0.12.5)
- tree-sitter CLI >= 0.26.1 and a C compiler (parser installation; `brew install tree-sitter-cli` on macOS)
- ripgrep (for telescope search functionality)
- Git (for plugin installation)
- For Rust development: rust-analyzer (automatically managed by Mason)
- For Lua development: lua-language-server (automatically managed by Mason)
- For formatting: stylua (for Lua files)
