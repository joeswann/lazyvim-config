local M = {}

-- nvim-cmp-compatible source (blink.compat will consume this)
local source = {}
source.new = function()
  return setmetatable({}, { __index = source })
end

function source:is_available()
  return vim.env.ANTHROPIC_API_KEY ~= nil -- silently disable if no key
end

function source:get_debug_name()
  return "ai_snippets"
end

-- Trigger on typical word chars and after punctuation like '.' '>' ':' etc.
function source:get_keyword_pattern()
  return [[\k\+]]
end

-- Adjust how aggressively we run (avoid spamming the API).
function source:get_trigger_characters()
  return { ".", ">", ":", "=", " ", "(" }
end

-- Core completion entrypoint
function source:complete(params, callback)
  -- Very small debounce: don’t call while typing fast
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local before = params.context.cursor_before_line or ""
  if before:match("^%s*$") then
    return callback({ items = {}, isIncomplete = true })
  end

  local util = require("ai_snippets.util")
  local ai = require("ai_snippets.engine")

  local ctx = util.build_context({
    max_before = 2400, -- chars before cursor
    max_after = 1200, -- chars after cursor
    max_open_buffers = 3,
    max_recent_diff_lines = 120,
  })

  -- Call AI for a single completion string
  ai.suggest(ctx, function(ok, text)
    if not ok or not text or text == "" then
      return callback({ items = {}, isIncomplete = true })
    end

    -- Trim dangerous leading newlines to avoid odd insert points
    text = text:gsub("^\n+", "")

    local items = {
      {
        label = (text:gsub("\n", "↵ "):sub(1, 120)),
        insertText = text,
        documentation = {
          kind = "markdown",
          value = "Smart snippet (AI-aware) based on your file, recent edits, and open buffers.",
        },
        -- Prefer textEdit over insertText when supported
        -- blink.compat handles mapping; keep it simple
      },
    }
    callback({ items = items, isIncomplete = true })
  end)
end

-- Blink compat expects a cmp-style registration
function M.register()
  local ok, cmp = pcall(require, "cmp")
  if not ok then
    return
  end
  cmp.register_source("ai_snippets", source.new())
end

return M
