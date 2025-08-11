local M = {}

-- Import required dependencies
local has_notify, notify = pcall(require, "notify")

-- Function to show toast notification
function M.show_toast(message, level)
  if has_notify then
    notify(message, level or "info", {
      title = "Claude Format",
      timeout = 3000,
      animate = true,
    })
  else
    vim.notify(message, vim.log.levels[level:upper()] or vim.log.levels.INFO)
  end
end

-- Function to get component name from current buffer if it exists
function M.get_current_component_name()
  local current_file = vim.fn.expand("%:t")
  if current_file == "" then
    return nil
  end
  return current_file:match("^(.+)%.[^.]+$") -- Matches filename without extension
end

-- Function to set cursor position inside a specific pattern
function M.set_cursor_after_pattern(pattern)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  for i, line in ipairs(lines) do
    if line:match(pattern) then
      vim.api.nvim_win_set_cursor(0, { i + 1, 6 })
      break
    end
  end
end

function M.get_open_buffers_content(current_buf)
  local context = {}

  -- Get list of all buffers
  local buffers = vim.api.nvim_list_bufs()

  for _, bufnr in ipairs(buffers) do
    -- Check if buffer is loaded and not the current buffer
    if vim.api.nvim_buf_is_loaded(bufnr) and bufnr ~= current_buf then
      local bufname = vim.api.nvim_buf_get_name(bufnr)
      -- Skip unnamed buffers and non-file buffers
      if bufname and bufname ~= "" and not bufname:match("^%a+://") then
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        if #lines > 0 then
          table.insert(
            context,
            string.format(
              "\nFile: %s\n----\n%s\n----\n",
              vim.fn.fnamemodify(bufname, ":~:."),
              table.concat(lines, "\n")
            )
          )
        end
      end
    end
  end

  return table.concat(context, "\n")
end

return M
