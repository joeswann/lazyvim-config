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
  local has_anthropic = vim.env.ANTHROPIC_API_KEY ~= nil

  local enabled = has_anthropic
  -- print("[AI_SNIPPETS] Enabled:", enabled)
  return enabled
end

function source:get_trigger_characters()
  -- Enhanced trigger characters for better AI completion timing
  return {
    ".",
    ">",
    ":",
    "=",
    " ",
    "(",
    "[",
    "{", -- Original triggers
    "\n",
    "}",
    ")",
    "]",
    ";",
    ",", -- Additional triggers for snippet expansion
    "f",
    "c",
    "i",
    "a",
    "v",
    "l",
    "d", -- Common word starts that benefit from AI
  }
end

function source:get_completions(ctx, callback)
  -- print("[AI_SNIPPETS] get_completions called")

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
    -- print("[AI_SNIPPETS] Debounce complete, making request...")

    self.current_cancel_fn = self:get_direct_completions(ctx, callback)
  end, 300)

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
  local ai = require("ai_snippets.engine")

  local context = context_builder.build_context({
    max_before = 2400,
    max_after = 1200,
    max_open_buffers = 3,
    max_recent_diff_lines = 120,
  })

  -- print("Item context:", vim.inspect(context))

  return ai.suggest(context, function(ok, completions)
    if ok and completions then
      self:process_completions(completions, callback, ctx)
    else
      callback({ items = {}, is_incomplete_backward = false, is_incomplete_forward = false })
    end
  end)
end

function source:process_completions(completions, callback, ctx)
  if not completions or #completions == 0 then
    return callback({ items = {}, is_incomplete_backward = false, is_incomplete_forward = false })
  end

  local items = {}
  for i, completion in ipairs(completions) do
    local text = completion.completion -- Changed from completion.text
    local label = completion.label or (text:gsub("\n", "↵"):sub(1, 60) .. (text:len() > 60 and "..." or ""))

    --- @type lsp.CompletionItem
    local item = {
      label = label,
      detail = "AI #" .. i,
      textEdit = {
        newText = text,
        range = {
          start = { line = ctx.cursor[1] - 1, character = ctx.cursor[2] },
          ["end"] = { line = ctx.cursor[1] - 1, character = ctx.cursor[2] },
        },
      },
      -- Store additionalTextEdits for use in resolve
      data = {
        additionalTextEdits = completion.additionalTextEdits,
      },
    }
    table.insert(items, item)
  end

  callback({
    items = items,
    is_incomplete_backward = false,
    is_incomplete_forward = false,
  })

  return function() end
end

function source:resolve(item, callback)
  item = vim.deepcopy(item)

  -- Add additionalTextEdits if they were provided by the AI
  if item.data and item.data.additionalTextEdits then
    item.additionalTextEdits = item.data.additionalTextEdits
  end

  -- Optional: Add documentation
  item.documentation = {
    kind = "markdown",
    value = "AI-generated completion" .. (item.additionalTextEdits and " (includes imports)" or ""),
  }

  callback(item)
end

return source
