--- @module 'blink.cmp'
--- @class blink.cmp.Source
local source = {}

function source.new(opts)
  local self = setmetatable({}, { __index = source })
  self.opts = opts or {}
  self.debounce_timer = nil
  self.current_cancel_fn = nil
  return self
end

function source:enabled()
  -- print("[AI_SNIPPETS] Checking enabled status...")
  local has_openrouter = vim.env.OPENROUTER_API_KEY ~= nil
  local has_anthropic = vim.env.ANTHROPIC_API_KEY ~= nil
  -- print("[AI_SNIPPETS] OpenRouter key:", has_openrouter)
  -- print("[AI_SNIPPETS] Anthropic key:", has_anthropic)

  local enabled = has_openrouter or has_anthropic
  -- print("[AI_SNIPPETS] Enabled:", enabled)
  return enabled
end

function source:get_trigger_characters()
  -- Enhanced trigger characters for better AI completion timing
  return { 
    ".", ">", ":", "=", " ", "(", "[", "{",  -- Original triggers
    "\n", "}", ")", "]", ";", ",",          -- Additional triggers for snippet expansion
    "f", "c", "i", "a", "v", "l", "d"      -- Common word starts that benefit from AI
  }
end

function source:get_completions(ctx, callback)
  print("[AI_SNIPPETS] get_completions called")

  local before_line = ctx.line and ctx.line:sub(1, ctx.cursor[2]) or ""

  if before_line:match("^%s*$") then
    -- print("[AI_SNIPPETS] Empty line, returning no items")
    return callback({ items = {}, is_incomplete_backward = false, is_incomplete_forward = false })
  end

  -- Cancel any existing request
  if self.current_cancel_fn then
    self.current_cancel_fn()
    self.current_cancel_fn = nil
  end

  -- Cancel existing debounce timer
  if self.debounce_timer then
    self.debounce_timer:stop()
    self.debounce_timer = nil
  end

  -- Debounce the request (750ms like copilot)
  self.debounce_timer = vim.defer_fn(function()
    self.debounce_timer = nil
    print("[AI_SNIPPETS] Debounce complete, making request...")

    self.current_cancel_fn = self:get_direct_completions(ctx, callback)
  end, 200)

  -- Return cancel function that cancels both debounce and request
  return function()
    if self.debounce_timer then
      self.debounce_timer:stop()
      self.debounce_timer = nil
    end
    if self.current_cancel_fn then
      self.current_cancel_fn()
      self.current_cancel_fn = nil
    end
  end
end

function source:get_direct_completions(ctx, callback)
  local context_builder = require("ai_context.builder")
  local mcp = require("ai_core.mcp")
  local ai = require("ai_snippets.engine")

  local context = context_builder.build_context({
    max_before = 2400,
    max_after = 1200,
    max_open_buffers = 3,
    max_recent_diff_lines = 120,
  })

  -- Try MCP first if available, otherwise fall back to regular AI engine
  if mcp.is_available() then
    return mcp.get_completions(context, function(ok, completions)
      if ok and completions then
        self:process_completions(completions, callback, ctx)
      else
        callback({ items = {}, is_incomplete_backward = false, is_incomplete_forward = false })
      end
    end)
  else
    return ai.suggest(context, function(ok, completions)
      if ok and completions then
        self:process_completions(completions, callback, ctx)
      else
        callback({ items = {}, is_incomplete_backward = false, is_incomplete_forward = false })
      end
    end)
  end
end

function source:process_completions(completions, callback, ctx)
  if not completions or #completions == 0 then
    return callback({ items = {}, is_incomplete_backward = false, is_incomplete_forward = false })
  end

  local items = {}
  for i, text in ipairs(completions) do
    if type(text) == "string" and text:gsub("%s", "") ~= "" then
      -- Clean up the text - keep single line for now but preserve intent
      local clean_text = text:gsub("^\n+", ""):gsub("%s+$", "")

      -- Create textEdit to replace from beginning of line to cursor position
      local current_line = ctx.line or ""
      local line_before_cursor = current_line:sub(1, ctx.cursor[2])
      
      -- Find the start of meaningful content (skip whitespace)
      local start_col = line_before_cursor:match("^%s*()")
      if not start_col then start_col = 1 end
      
      -- Check if text looks like it could benefit from snippet expansion
      local has_placeholders = clean_text:match("%$%d") or clean_text:match("%${%d") 
      local insert_format = has_placeholders and vim.lsp.protocol.InsertTextFormat.Snippet 
                                            or vim.lsp.protocol.InsertTextFormat.PlainText
      
      -- Convert simple patterns to snippet format if beneficial
      local snippet_text = clean_text
      if not has_placeholders then
        -- Convert common patterns to snippets with placeholders
        snippet_text = snippet_text:gsub("(%w+)%((.-)%)", "%1(${1:%2})") -- function calls
        snippet_text = snippet_text:gsub("= ([^;,\n]+)", "= ${1:%1}") -- assignments
        if snippet_text ~= clean_text then
          insert_format = vim.lsp.protocol.InsertTextFormat.Snippet
        end
      end
      
      --- @type lsp.CompletionItem
      local item = {
        label = clean_text:gsub("\n", "↵"):sub(1, 60) .. (clean_text:len() > 60 and "..." or ""),
        insertTextFormat = insert_format,
        kind = require("blink.cmp.types").CompletionItemKind.Snippet,
        sortText = string.format("\x00%02d", i), -- maintain order
        detail = "AI Generated #" .. i,
        documentation = {
          kind = "markdown",
          value = "```" .. (ctx.line and vim.bo.filetype or "text") .. "\n" .. clean_text .. "\n```"
        },
        textEdit = {
          range = {
            start = { line = ctx.cursor[1] - 1, character = start_col - 1 },
            ["end"] = { line = ctx.cursor[1] - 1, character = ctx.cursor[2] }
          },
          newText = snippet_text
        }
      }
      table.insert(items, item)
    end
  end

  print("[AI_SNIPPETS] Generated", #items, "completions")
  callback({
    items = items,
    is_incomplete_backward = false,
    is_incomplete_forward = false,
  })
end

function source:resolve(item, callback)
  item = vim.deepcopy(item)
  item.documentation = {
    kind = "markdown",
    value = "AI-generated code completion based on context.",
  }
  callback(item)
end

return source
