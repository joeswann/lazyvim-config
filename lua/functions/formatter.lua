-- File: lua/functions/formatter.lua
local M = {}

local utils = require("functions.utils")
local claude = require("functions.claude")

function M.format_claude_response()
  vim.ui.input({ prompt = "Enter prompt for Claude: " }, function(prompt)
    if not prompt then
      return
    end

    -- Get current buffer content
    local current_buf = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(current_buf, 0, -1, false)
    local content = table.concat(lines, "\n")

    -- Get context from other buffers
    local context = utils.get_open_buffers_content(current_buf)

    -- Show loading toast
    utils.show_toast("Processing with Claude...", "info")

    -- Request formatting from Claude with user prompt and context
    claude.format_text(content, prompt, context, function(result)
      if result.success then
        -- Save current view state
        local view = vim.fn.winsaveview()

        -- Replace buffer content with code
        vim.api.nvim_buf_set_lines(current_buf, 0, -1, false, vim.split(result.code, "\n"))

        -- Restore view
        vim.fn.winrestview(view)

        -- Show Claude's comments in toast if any
        if result.comments then
          utils.show_toast(result.comments, "info")
        end
      else
        utils.show_toast("Failed: " .. (result.message or "Unknown error"), "error")
      end
    end)
  end)
end

return M
