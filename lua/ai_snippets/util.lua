local U = {}

local function clamp_tail(s, n)
  if #s <= n then
    return s
  end
  return s:sub(#s - n + 1)
end

local function clamp_head(s, n)
  if #s <= n then
    return s
  end
  return s:sub(1, n)
end

local function get_open_buffers(max_bufs, max_chars_per)
  local bufs = {}
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if #bufs >= max_bufs then
      break
    end
    if vim.api.nvim_buf_is_loaded(b) then
      local name = vim.api.nvim_buf_get_name(b)
      if name ~= "" and b ~= vim.api.nvim_get_current_buf() then
        local lines = vim.api.nvim_buf_get_lines(b, 0, -1, false)
        local text = table.concat(lines, "\n")
        table.insert(bufs, {
          path = vim.fn.fnamemodify(name, ":~:."),
          sample = clamp_head(text, max_chars_per or 1500),
        })
      end
    end
  end
  return bufs
end

local function get_recent_diff_lines(filepath, max_lines)
  -- Only current file to keep it cheap
  local cmd = { "git", "diff", "-U0", "--no-color", "--", filepath }
  local ok, out = pcall(vim.fn.systemlist, cmd)
  if not ok or vim.v.shell_error ~= 0 then
    return nil
  end
  local lines = {}
  for _, l in ipairs(out) do
    if not l:match("^diff ") and not l:match("^index ") and not l:match("^@@") then
      table.insert(lines, l)
      if #lines >= max_lines then
        break
      end
    end
  end
  if #lines == 0 then
    return nil
  end
  return table.concat(lines, "\n")
end

function U.build_context(opts)
  opts = opts or {}
  local ft = vim.bo.filetype
  local file = vim.fn.expand("%:p")
  local filename = vim.fn.expand("%:t")
  local cwd = vim.loop.cwd()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local all = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  local before = all:sub(1, vim.api.nvim_buf_get_offset(0, row - 1) + col)
  local after = all:sub(vim.api.nvim_buf_get_offset(0, row - 1) + col + 1)

  local ctx = {
    language = ft,
    filename = filename,
    filepath = vim.fn.fnamemodify(file, ":~:."),
    cwd = cwd,
    cursor = { row = row, col = col },
    before = clamp_tail(before, opts.max_before or 2400),
    after = clamp_head(after, opts.max_after or 1200),
    open_buffers = get_open_buffers(opts.max_open_buffers or 2, 1200),
    recent_edits = get_recent_diff_lines(file, opts.max_recent_diff_lines or 120) or "",
  }
  return ctx
end

return U
