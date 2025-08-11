local M = {}

-- nvim-cmp-compatible source (blink.compat will consume this)
local source = {}
source.new = function()
  return setmetatable({}, { __index = source })
end

function source:is_available()
  local available = vim.env.ANTHROPIC_API_KEY ~= nil
  print("[AI_SNIPPETS] is_available:", available)
  return available
end

function source:get_debug_name()
  return "ai_snippets"
end

-- Use standard keyword pattern for better compatibility
function source:get_keyword_pattern()
  return [[\k\+]]
end

-- Keep triggers modest to avoid spam
function source:get_trigger_characters()
  return { ".", ">", ":", "=", " ", "(" }
end

-- Core completion entrypoint
function source:complete(params, callback)
  local before_line = params.context.cursor_before_line or ""
  if before_line:match("^%s*$") then
    return callback({ items = {}, isIncomplete = true })
  end

  local util = require("ai_snippets.util")
  local ai = require("ai_snippets.engine")

  local ctx = util.build_context({
    max_before = 2400,
    max_after = 1200,
    max_open_buffers = 3,
    max_recent_diff_lines = 120,
  })

  ai.suggest(ctx, function(ok, text)
    if not ok or not text or text == "" then
      return callback({ items = {}, isIncomplete = true })
    end

    -- Clean up the text and make it single line for testing
    text = text:gsub("^\n+", ""):gsub("\n.*", "")  -- Take only first line
    local label = text:sub(1, 50)  -- Shorter label

    local item = {
      label = text,  -- Use the actual text as label
      insertText = text,
      insertTextFormat = 1, -- Plain text  
      kind = 1, -- Text completion kind
      sortText = "\x00" .. text, -- float to the top within our provider
    }

    print("[AI_SNIPPETS] Generated item:", vim.inspect(item))
    print("[AI_SNIPPETS] Callback structure:", vim.inspect({ items = { item }, isIncomplete = false }))
    callback({ items = { item }, isIncomplete = false })
  end)
end

-- Expose the source constructor
function M.new()
  return source.new()
end

-- Blink compat expects a cmp-style registration
function M.register()
  local ok, cmp = pcall(require, "cmp")
  if not ok then
    return
  end
  cmp.register_source("ai_snippets", M.new())
end

return M
