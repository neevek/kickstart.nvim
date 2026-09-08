local M = {}
local active

local function locations(result)
  if not result or vim.tbl_isempty(result) then
    return {}
  end
  return vim.islist(result) and result or { result }
end

local function normalize(loc)
  return { uri = loc.uri or loc.targetUri, range = loc.range or loc.targetSelectionRange }
end

function M.cancel()
  if not active then
    return
  end
  local previous = active
  active = nil
  for id in pairs(previous.requests) do
    previous.client:cancel_request(id)
  end
  for buf in pairs(previous.headers) do
    if vim.api.nvim_buf_is_valid(buf) and not vim.bo[buf].modified and not vim.bo[buf].buflisted and #vim.fn.win_findbuf(buf) == 0 then
      pcall(vim.api.nvim_buf_delete, buf, {})
    end
  end
end

function M.implementations()
  M.cancel()
  local buf = vim.api.nvim_get_current_buf()
  local method = 'textDocument/implementation'
  local clients = vim.lsp.get_clients { bufnr = buf, method = method }
  if #clients == 0 then
    method = 'textDocument/definition'
    clients = vim.lsp.get_clients { bufnr = buf, method = method }
  end
  local client
  for _, candidate in ipairs(clients) do
    client = candidate
    if candidate.name == 'clangd' then
      break
    end
  end
  if not client then
    vim.notify('No navigation provider attached', vim.log.levels.WARN)
    return
  end

  local job = { client = client, requests = {}, headers = {}, buf = buf, win = vim.api.nvim_get_current_win() }
  active = job
  local function current()
    return active == job and vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_get_current_buf() == buf and vim.api.nvim_get_current_win() == job.win
  end

  local function open_header(uri)
    local path = vim.uri_to_fname(uri)
    local header = vim.fn.bufnr(path)
    if header == -1 then
      local size = vim.fn.getfsize(path)
      if size < 0 or size > 1024 * 1024 then
        return false
      end
      header = vim.fn.bufadd(path)
      job.headers[header] = true
    end
    -- clangd needs a didOpen for definition requests into another document.
    vim.fn.bufload(header)
    return vim.lsp.buf_attach_client(header, client.id)
  end

  local function request(method, params, timeout, callback)
    local done, id = false, nil
    local function finish(err, result)
      if done then
        return
      end
      done = true
      if id then
        job.requests[id] = nil
      end
      if current() then
        callback(err, result)
      elseif active == job then
        M.cancel()
      end
    end
    local ok
    ok, id = client:request(method, params, finish, buf)
    if not ok then
      finish { message = 'Language server stopped' }
      return
    end
    if not done then
      job.requests[id] = true
    end
    vim.defer_fn(function()
      if done then
        return
      end
      client:cancel_request(id)
      finish { message = 'Language server request timed out' }
    end, timeout)
  end

  local function present(found, title)
    local include_tests = require('custom.search').in_unittest(vim.fn.getcwd())
    local visible, seen = {}, {}
    for _, loc in ipairs(found) do
      local path = vim.uri_to_fname(loc.uri)
      local key = loc.uri .. ':' .. loc.range.start.line .. ':' .. loc.range.start.character
      if not seen[key] and (include_tests or not path:find('unittest', 1, true)) then
        seen[key] = true
        visible[#visible + 1] = loc
      end
    end
    found = visible
    M.cancel()
    if #found == 0 then
      vim.notify 'No destinations outside the excluded unittest paths'
      return
    end
    if #found == 1 then
      vim.lsp.util.show_document(found[1], client.offset_encoding, { focus = true, reuse_win = true })
      return
    end
    local items = vim.lsp.util.locations_to_items(found, client.offset_encoding)
    for _, item in ipairs(items) do
      if not item.bufnr and item.filename then
        item.bufnr = vim.fn.bufadd(item.filename)
      end
      if item.bufnr and item.bufnr > 0 then
        vim.bo[item.bufnr].buflisted = true
      end
    end
    vim.fn.setqflist({}, ' ', { title = title, items = items })
    require('telescope.builtin').quickfix { prompt_title = title }
  end

  local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
  local function definitions()
    request('textDocument/definition', params, 5000, function(err, result)
      if err then
        M.cancel()
        vim.notify(err.message, vim.log.levels.WARN)
        return
      end
      local found = vim.tbl_map(normalize, locations(result))
      if #found == 0 then
        M.cancel()
        vim.notify 'No overrides or definition found for this symbol'
        return
      end
      present(found, 'Definitions')
    end)
  end

  if method == 'textDocument/definition' then
    definitions()
    return
  end

  request(method, params, 5000, function(err, result)
    if err then
      M.cancel()
      vim.notify(err.message, vim.log.levels.WARN)
      return
    end
    local declarations = locations(result)
    if #declarations == 0 then
      definitions()
      return
    end
    local results, next_index, running, completed = {}, 1, 0, 0
    local shown = false
    local function show()
      if shown or not current() then
        if active == job and not current() then
          M.cancel()
        end
        return
      end
      shown = true
      local seen, found = {}, {}
      for i, decl in ipairs(declarations) do
        local loc = normalize(results[i] or decl)
        if loc.uri and loc.range then
          local key = loc.uri .. ':' .. loc.range.start.line .. ':' .. loc.range.start.character
          if not seen[key] then
            seen[key] = true
            found[#found + 1] = loc
          end
        end
      end
      present(found, 'Override Implementations')
    end
    local function pump()
      if not current() or shown then
        return
      end
      while running < 4 and next_index <= #declarations do
        local i = next_index
        next_index = next_index + 1
        local loc = normalize(declarations[i])
        if not loc.uri or not loc.range then
          completed = completed + 1
        elseif not loc.uri:match '%.h$' and not loc.uri:match '%.hpp$' and not loc.uri:match '%.hh$' and not loc.uri:match '%.hxx$' then
          results[i] = declarations[i]
          completed = completed + 1
        else
          local ok, attached = pcall(open_header, loc.uri)
          if not ok or not attached then
            completed = completed + 1
          else
            running = running + 1
            request(
              'textDocument/definition',
              {
                textDocument = { uri = loc.uri },
                position = loc.range.start,
              },
              3000,
              function(_, definitions)
                for _, def in ipairs(locations(definitions)) do
                  local uri = def.uri or def.targetUri or ''
                  if uri:match '%.c$' or uri:match '%.cc$' or uri:match '%.cpp$' or uri:match '%.cxx$' or uri:match '%.m$' or uri:match '%.mm$' then
                    results[i] = def
                    break
                  end
                end
                running = running - 1
                completed = completed + 1
                vim.schedule(pump)
              end
            )
          end
        end
      end
      if completed == #declarations then
        show()
      end
    end
    pump()
    -- Keep declarations as a useful fallback if the background index is still warming.
    vim.defer_fn(show, 8000)
  end)
end

return M
