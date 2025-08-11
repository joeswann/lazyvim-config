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

-- We’ll let Blink decide the word normally; the real replacement happens via textEdit.
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

    text = text:gsub("^\n+", "")

    local row1, _ = unpack(vim.api.nvim_win_get_cursor(0))
    local row0 = row1 - 1
    local curline = vim.api.nvim_get_current_line()

    -- convert to UTF-16 “character” count for LSP-style ranges (Blink handles this via compat)
    local function utf16_len(s)
      local ok_util, util = pcall(require, "vim.lsp.util")
      if ok_util and util then
        local byteidx = #s
        local ok2, u16 = pcall(util._str_utfindex_enc, s, byteidx, "utf-16")
        if ok2 and type(u16) == "number" then
          return u16
        end
      end
      return #s -- fine for ASCII
    end

    local ecol = utf16_len(curline)
    local label = (text:gsub("\n", "↵ "):sub(1, 120))

    local item = {
      label = label,

      -- Ask Blink to REPLACE the entire current line with our suggestion
      textEdit = {
        newText = text,
        range = {
          start = { line = row0, character = 0 },
          ["end"] = { line = row0, character = ecol },
        },
      },

      insertTextFormat = 1, -- Plain text
      filterText = text,
      sortText = "\x00" .. label, -- float to the top within our provider
      documentation = {
        kind = "markdown",
        value = "Smart snippet (AI-aware) — replaces current line.",
      },
    }

    callback({ items = { item }, isIncomplete = false })
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
