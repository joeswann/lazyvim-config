local M = {}
local ns = vim.api.nvim_create_namespace("ai-ghost")
local pending = { text = "", row = 0, col = 0 }
local timer = vim.uv.new_timer()
local util = require("ai_snippets.util")
local core = require("ai_core.core")

local function clear()
  vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
  pending.text = ""
end

local function place(row, col, text)
  clear()
  if text == "" then
    return
  end
  vim.api.nvim_buf_set_extmark(0, ns, row, col, {
    virt_text = { { text, "Comment" } },
    virt_text_pos = "inline",
    hl_mode = "combine",
  })
  pending = { text = text, row = row, col = col }
end

local function request()
  local ctx = util.build_context({
    max_before = 2400,
    max_after = 800,
    max_open_buffers = 2,
    max_recent_diff_lines = 80,
  })
  core.suggest(ctx, function(ok, text)
    if not ok then
      return clear()
    end
    text = (text or ""):gsub("^\n+", "")
    place(ctx.cursor.row - 1, ctx.cursor.col, text)
  end)
end

function M.accept()
  if pending.text == "" then
    return
  end
  local row, col = pending.row, pending.col
  vim.api.nvim_buf_set_text(0, row, col, row, col, vim.split(pending.text, "\n"))
  clear()
end

function M.setup(opts)
  opts = opts or {}
  local debounce = tonumber(opts.debounce_ms or 180)

  vim.api.nvim_create_autocmd({ "InsertCharPre", "TextChangedI" }, {
    callback = function()
      if timer:is_active() then
        timer:stop()
      end
      timer:start(debounce, 0, vim.schedule_wrap(request))
    end,
  })
  vim.api.nvim_create_autocmd({ "ModeChanged", "CursorMoved", "InsertLeave", "BufLeave" }, { callback = clear })

  -- Accept key (does not conflict with Blink)
  vim.keymap.set("i", "<C-g>", M.accept, { desc = "Accept AI ghost text" })
end

return M
