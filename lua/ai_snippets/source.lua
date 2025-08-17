-- @module 'blink.cmp'
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
  return vim.env.ANTHROPIC_API_KEY ~= nil
end

function source:get_trigger_characters()
  return {
    ".",
    ">",
    ":",
    "=",
    " ",
    "(",
    "[",
    "{",
    "\n",
    "}",
    ")",
    "]",
    ";",
    ",",
    "f",
    "c",
    "i",
    "a",
    "v",
    "l",
    "d",
  }
end

function source:get_completions(ctx, callback)
  local before_line = ctx.line and ctx.line:sub(1, ctx.cursor[2]) or ""
  if before_line:match("^%s*$") then
    return callback({ items = {}, is_incomplete_backward = false, is_incomplete_forward = false })
  end

  if self.current_cancel_fn then
    self.current_cancel_fn()
    self.current_cancel_fn = nil
  end

  if self.debounce_timer then
    self.debounce_timer:stop()
    self.debounce_timer = nil
  end

  self.debounce_timer = vim.defer_fn(function()
    self.debounce_timer = nil
    self.current_cancel_fn = self:get_direct_completions(ctx, callback)
  end, 300)

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

  return ai.suggest(context, function(ok, completions)
    if ok and completions then
      self:process_completions(completions, callback, ctx)
    else
      callback({ items = {}, is_incomplete_backward = false, is_incomplete_forward = false })
    end
  end)
end
-- --- main ------------------------------------------------------------------

function source:process_completions(completions, callback, ctx)
  if not completions or #completions == 0 then
    return callback({ items = {}, is_incomplete_backward = false, is_incomplete_forward = false })
  end

  local items = {}
  for i, completion in ipairs(completions) do
    local newText = completion.newText or ""
    if newText ~= "" and completion.range then
      local label = (newText:gsub("\n", "↵"):sub(1, 60) .. (newText:len() > 60 and "..." or ""))

      print(vim.inspect(completion))

      --- @type lsp.CompletionItem
      local item = {
        label = label,
        detail = "AI #" .. i,
        textEdit = {
          newText = newText,
          range = completion.range,
        },
        data = {
          additionalTextEdits = completion.additionalTextEdits,
        },
      }

      print(vim.inspect(item))

      table.insert(items, item)
    end
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

  if item.data and item.data.additionalTextEdits then
    item.additionalTextEdits = item.data.additionalTextEdits
  end

  item.documentation = {
    kind = "markdown",
    value = "AI-generated completion" .. (item.additionalTextEdits and " (includes imports)" or ""),
  }

  callback(item)
end

return source
