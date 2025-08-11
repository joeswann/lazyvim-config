--- @module 'blink.cmp'
--- @class blink.cmp.Source
local source = {}

function source.new(opts)
  local self = setmetatable({}, { __index = source })
  self.opts = opts or {}
  return self
end

function source:enabled()
  return vim.env.ANTHROPIC_API_KEY ~= nil
end

function source:get_trigger_characters()
  return { ".", ">", ":", "=", " ", "(" }
end

function source:get_completions(ctx, callback)
  local before_line = ctx.line:sub(1, ctx.cursor[2])
  if before_line:match("^%s*$") then
    return callback({ items = {}, is_incomplete_backward = false, is_incomplete_forward = false })
  end

  local util = require("ai_snippets.util")
  local ai = require("ai_snippets.engine")

  local context = util.build_context({
    max_before = 2400,
    max_after = 1200,
    max_open_buffers = 3,
    max_recent_diff_lines = 120,
  })

  ai.suggest(context, function(ok, text)
    if not ok or not text or text == "" then
      return callback({ items = {}, is_incomplete_backward = false, is_incomplete_forward = false })
    end

    -- Clean up the text and make it single line for testing
    text = text:gsub("^\n+", ""):gsub("\n.*", "")  -- Take only first line

    --- @type lsp.CompletionItem
    local item = {
      label = text,
      insertText = text,
      insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
      kind = require('blink.cmp.types').CompletionItemKind.Text,
      sortText = "\x00" .. text, -- float to the top
    }

    print("[AI_SNIPPETS] Native blink item:", vim.inspect(item))
    callback({
      items = { item },
      is_incomplete_backward = false,
      is_incomplete_forward = false,
    })
  end)

  -- Return cancel function
  return function() end
end

function source:resolve(item, callback)
  item = vim.deepcopy(item)
  item.documentation = {
    kind = 'markdown',
    value = 'AI-generated code completion based on context.',
  }
  callback(item)
end

return source