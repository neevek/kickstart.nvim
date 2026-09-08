"""Verify the installed Neovim config through direct, session, and tree opening."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import threading


PROBE = r'''
local tree_error
local target = vim.env.NVIM_UI_MODE == 'ignored' and 'ApolloSDK.cpp' or 'example.cpp'
if vim.env.NVIM_UI_MODE == 'ignored' then
  vim.defer_fn(function() vim.cmd.edit(vim.env.NVIM_UI_IGNORED) end, 800)
end
local opened_from_tree = false
local function open_from_tree()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == 'NvimTree' then
      for line, text in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
        if text:find('example.cpp', 1, true) then
          vim.api.nvim_set_current_win(win)
          vim.api.nvim_win_set_cursor(win, {line, 0})
          require('nvim-tree.api').node.open.edit()
          return true
        end
      end
    end
  end
  return false
end

local started = vim.uv.hrtime()
local deadline = started + 10e9
local function check()
  if vim.env.NVIM_UI_MODE == 'tree' and not opened_from_tree then
    opened_from_tree = open_from_tree()
  end
  local plugins = require('lazy.core.config').plugins
  local state = {
    bufferline = plugins['bufferline.nvim']._.loaded ~= nil,
    tabline = vim.o.tabline,
    showtabline = vim.o.showtabline,
    tree_error = tree_error,
    ui_attached = #vim.api.nvim_list_uis() > 0,
  }
  -- Evaluating a hidden bufferline can itself set showtabline=2 and mask the regression.
  if state.bufferline and state.showtabline == 2 and state.tabline ~= '' then
    state.rendered = vim.api.nvim_eval_statusline(state.tabline, {use_tabline=true}).str
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.fs.basename(vim.api.nvim_buf_get_name(buf)) == target then
      state.file = vim.api.nvim_buf_get_name(buf)
      state.filetype = vim.bo[buf].filetype
      state.highlighting = vim.treesitter.highlighter.active[buf] ~= nil
      state.lsp = #vim.lsp.get_clients({bufnr = buf, name = 'clangd'}) > 0
    end
  end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == 'NvimTree' then
      state.tree_path = vim.api.nvim_win_call(win, function()
        local node = require('nvim-tree.api').tree.get_node_under_cursor()
        return node and node.absolute_path
      end)
    end
  end
  state.ready = state.bufferline and state.showtabline == 2 and state.tabline ~= ''
    and state.filetype == 'cpp' and state.highlighting and state.lsp and not tree_error
    and state.rendered and state.rendered:find(target, 1, true) ~= nil
  if vim.env.NVIM_UI_MODE ~= 'direct' then
    state.ready = state.ready and state.tree_path == state.file
  end
  if (state.ready and vim.uv.hrtime() - started >= 2e9) or vim.uv.hrtime() >= deadline then
    vim.fn.writefile({vim.json.encode(state)}, vim.env.NVIM_UI_OUTPUT)
    vim.cmd('qa!')
  else
    vim.defer_fn(check, 100)
  end
end
vim.defer_fn(check, 400)
'''


def run(args, directory, env):
    return subprocess.run(args, cwd=directory, env=env, capture_output=True,
                          text=True, errors='replace', timeout=20, check=True)


def run_terminal(args, directory, env):
    import fcntl
    import pty
    import re
    import struct
    import termios

    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 40, 180, 0, 0))
    output = []

    def drain():
        pending = b''
        while True:
            try:
                chunk = os.read(master, 65536)
                if not chunk:
                    break
                output.append(chunk)
                pending += chunk
                # Neovim 0.12 queries terminal colors before finishing TUI startup.
                for match in re.finditer(rb'\x1b\](10|11);\?(?:\x07|\x1b\\)', pending):
                    color = b'ffff/ffff/ffff' if match[1] == b'10' else b'0000/0000/0000'
                    os.write(master, b'\x1b]' + match[1] + b';rgb:' + color + b'\x1b\\')
                pending = pending[-32:] if not re.search(rb'\x07|\x1b\\', pending) else b''
            except OSError:
                break

    process = subprocess.Popen(args, cwd=directory, env=dict(env, TERM='xterm-256color'),
                               stdin=slave, stdout=slave, stderr=slave, start_new_session=True)
    os.close(slave)
    reader = threading.Thread(target=drain, daemon=True)
    reader.start()
    try:
        code = process.wait(timeout=20)
    except subprocess.TimeoutExpired as error:
        raise AssertionError('Terminal check timed out: ' + repr(b''.join(output)[-2500:])) from error
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()
        reader.join(timeout=1)
        os.close(master)
    text = b''.join(output).decode(errors='replace')[-3000:]
    if code:
        raise AssertionError(f'Terminal Neovim exited {code}: {text}')
    return subprocess.CompletedProcess(args, code, stderr=text)


def main():
    config = Path(__file__).resolve().parents[1]
    compiler = shutil.which('clang++')
    if not compiler:
        raise RuntimeError('clang++ is required for the LSP startup check')
    with tempfile.TemporaryDirectory(prefix='nvim-startup-ui-') as directory:
        root = Path(directory).resolve()
        source = root / 'example.cpp'
        source.write_text('int main() { return 0; }\n', encoding='utf-8')
        ignored = root / 'sdk-cxx/include/ApolloSDK.cpp'
        ignored.parent.mkdir(parents=True)
        ignored.write_text('int sdk_value() { return 0; }\n', encoding='utf-8')
        (root / '.gitignore').write_text('/sdk-cxx/include/\n', encoding='utf-8')
        run(['git', 'init', '-q'], root, os.environ.copy())
        (root / 'compile_commands.json').write_text(json.dumps([{
            'directory': str(root), 'file': str(file),
            'arguments': [compiler, '-std=c++17', '-c', str(file)],
        } for file in (source, ignored)]), encoding='utf-8')
        probe = root / 'probe.lua'
        probe.write_text(PROBE, encoding='utf-8')
        session = root / '.session.vim'
        env = dict(os.environ, NVIM_UI_SESSION=str(session), NVIM_UI_IGNORED=str(ignored))
        run(['nvim', '--headless', '-n', '-R', '-u', 'NONE', '-i', 'NONE', str(source),
             '+lua vim.cmd("mksession! " .. vim.fn.fnameescape(vim.env.NVIM_UI_SESSION))', '+qa!'], root, env)
        original_session = session.read_text(encoding='utf-8')
        modes = [('session', [], False), ('direct', [str(source)], False),
                 ('tree', [str(root)], False), ('ignored', [], False)]
        if os.name == 'posix':
            modes += [('session', [], True), ('ignored', [], True)]
        for mode, files, terminal in modes:
            session.write_text(original_session, encoding='utf-8')
            label = mode + ('-terminal' if terminal else '-headless')
            output = root / (label + '.json')
            runner = run_terminal if terminal else run
            args = ['nvim'] + ([] if terminal else ['--headless'])
            result = runner(args + ['-n', '-R', '-u', str(config / 'init.lua'),
                                   '-i', 'NONE', *files, '+luafile ' + str(probe)], root,
                            dict(env, NVIM_UI_MODE=mode, NVIM_UI_OUTPUT=str(output)))
            state = json.loads(output.read_text(encoding='utf-8'))
            if not state.get('ready') or state['ui_attached'] != terminal:
                raise AssertionError(f'{label}: {state}\n{result.stderr}')
            print(f'{label}: rendered bufferline, file highlighting, clangd, and tree selection passed', flush=True)


if __name__ == '__main__':
    main()
