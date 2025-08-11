-- File: lua/functions/formatter.lua
local M = {}

local utils = require("ai_functions.utils")
local claude = require("ai_functions.claude")

-- Helper function to get visual selection
local function get_visual_selection()
  -- Get positions BEFORE any mode changes
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local start_row = start_pos[2] - 1
  local start_col = start_pos[3] - 1
  local end_row = end_pos[2] - 1
  local end_col = end_pos[3]

  -- Get the selected lines
  local lines = vim.api.nvim_buf_get_lines(0, start_row, end_row + 1, false)

  -- If nothing is selected, return nil
  if #lines == 0 then
    return nil
  end

  -- Adjust the first and last line for partial selections
  if #lines == 1 then
    lines[1] = lines[1]:sub(start_col + 1, end_col)
  else
    lines[1] = lines[1]:sub(start_col + 1)
    lines[#lines] = lines[#lines]:sub(1, end_col)
  end

  return {
    text = table.concat(lines, "\n"),
    start_row = start_row,
    end_row = end_row,
    start_col = start_col,
    end_col = end_col,
    mode = vim.fn.visualmode(), -- Store the visual mode type
  }
end

function M.format_claude_response()
  -- Get visual selection info BEFORE any mode changes or prompts
  local selection = nil
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then -- "\22" = Ctrl-V (block)
    selection = get_visual_selection()
  end

  -- Return to normal mode while preserving marks
  if selection then
    vim.cmd("normal! gv") -- Reselect the visual selection
    vim.cmd("normal! y") -- Yank it to preserve the marks
    vim.cmd("normal! gv") -- Keep it selected
  end

  vim.ui.input({ prompt = "Enter prompt for Claude: " }, function(prompt)
    if not prompt then
      -- Restore visual selection if cancelled
      if selection then
        vim.cmd("normal! gv")
      end
      return
    end

    -- Get current buffer
    local current_buf = vim.api.nvim_get_current_buf()

    -- Get full buffer content for context
    local full_buffer_lines = vim.api.nvim_buf_get_lines(current_buf, 0, -1, false)
    local full_buffer_content = table.concat(full_buffer_lines, "\n")

    local content_to_process
    if selection then
      content_to_process = selection.text
    else
      content_to_process = full_buffer_content
    end

    -- Get context from other buffers
    local context = utils.get_open_buffers_content(current_buf)

    -- Add current buffer to context with clear marker
    context = string.format("%s\nCurrent Buffer Full Content:\n----\n%s\n----\n", context, full_buffer_content)

    -- Show loading toast
    utils.show_toast("Processing with Claude...", "info")

    -- Request formatting from Claude with user prompt and context
    claude.format_text(content_to_process, prompt, context, function(result)
      if result.success then
        -- Save current view state
        local view = vim.fn.winsaveview()

        if selection then
          -- Replace only the selected text
          local lines = vim.split(result.code, "\n")
          vim.api.nvim_buf_set_text(
            current_buf,
            selection.start_row,
            selection.start_col,
            selection.end_row,
            selection.end_col,
            lines
          )

          -- Reselect the new text
          vim.schedule(function()
            -- Calculate end position for new selection
            local new_end_row = selection.start_row
            local new_end_col = selection.start_col
            if #lines > 1 then
              new_end_row = selection.start_row + #lines - 1
              new_end_col = #lines[#lines]
            else
              new_end_col = selection.start_col + #lines[1]
            end

            -- Restore visual selection with new text
            vim.cmd("normal! " .. selection.start_row + 1 .. "G" .. selection.start_col + 1 .. "|")
            vim.cmd("normal! v")
            vim.cmd("normal! " .. new_end_row + 1 .. "G" .. new_end_col .. "|")
          end)
        else
          -- Replace entire buffer
          vim.api.nvim_buf_set_lines(current_buf, 0, -1, false, vim.split(result.code, "\n"))
        end

        -- Restore view
        vim.fn.winrestview(view)

        -- Show Claude's comments in toast if any
        if result.comments then
          utils.show_toast(result.comments, "info")
        end
      else
        -- Restore visual selection on error
        if selection then
          vim.schedule(function()
            vim.cmd("normal! gv")
          end)
        end
        utils.show_toast("Failed: " .. (result.message or "Unknown error"), "error")
      end
    end)
  end)
end

return M
