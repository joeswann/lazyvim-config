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

-- function source:enabled()
--   return vim.env.ANTHROPIC_API_KEY ~= nil
-- end

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
  local context_builder = require("ai_context.builder")
  local ai = require("ai_suggestions.engine")

  -- local before_line = ctx.line and ctx.line:sub(1, ctx.cursor[2]) or ""
  -- if before_line:match("^%s*$") then
  --   return callback({ items = {}, is_incomplete_backward = false, is_incomplete_forward = false })
  -- end

  local context = context_builder.build_context()

  ai.suggest(context, function(ok, completions)
    if ok and completions then
      if not completions or #completions == 0 then
        return callback({ items = {}, is_incomplete_backward = false, is_incomplete_forward = false })
      end

      local items = {}

      for _, completion in ipairs(completions) do
        if completion.newText ~= "" and completion.range then
          local label = (
            completion.newText:gsub("\n", "↵"):sub(1, 60) .. (completion.newText:len() > 60 and "..." or "")
          )

          --- @type lsp.CompletionItem
          local item = {
            label = "[AI] " .. label,
            -- detail = "AI #" .. i,
            -- textEdit = {
            -- newText = completion.newText,
            -- range = completion.range,
            -- },
            insertText = completion.newText,
            data = {
              additionalTextEdits = completion.additionalTextEdits,
            },
          }

          table.insert(items, item)
        end
      end

      print("Returning completion item")
      print(vim.inspect(items))

      callback({
        items = vim.deepcopy(items),
        is_incomplete_backward = false,
        is_incomplete_forward = false,
      })
    else
      callback({ items = {}, is_incomplete_backward = false, is_incomplete_forward = false })
    end
  end)

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
