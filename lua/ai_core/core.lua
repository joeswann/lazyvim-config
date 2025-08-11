-- File: lua/ai_core/core.lua
local M = {}
local curl = require("plenary.curl")

-- Config via env; sensible defaults
local MODEL = vim.env.AI_ENGINE_MODEL or "claude-3-5-sonnet-20240620"
local MAX_TOKENS = tonumber(vim.env.AI_ENGINE_MAX_TOKENS or "120")
local TEMP_COMPLETION = tonumber(vim.env.AI_ENGINE_TEMP_COMPLETION or "0.2")
local TEMP_FORMAT = tonumber(vim.env.AI_ENGINE_TEMP_FORMAT or "0.3")

local function post_anthropic(payload, cb)
  local key = vim.env.ANTHROPIC_API_KEY
  if not key then
    return cb(false, "ANTHROPIC_API_KEY not set")
  end

  curl.post("https://api.anthropic.com/v1/messages", {
    headers = {
      ["x-api-key"] = key,
      ["anthropic-version"] = "2023-06-01",
      ["content-type"] = "application/json",
    },
    body = vim.json.encode(payload),
    callback = vim.schedule_wrap(function(res)
      if not res or res.status ~= 200 then
        return cb(false, (res and res.body) or "HTTP error")
      end
      local ok, data = pcall(vim.json.decode, res.body or "")
      if not ok or not data or not data.content or not data.content[1] then
        return cb(false, "Bad response")
      end
      local text = (data.content[1].text or ""):gsub("^```%w*\n", ""):gsub("\n```%s*$", "")
      cb(true, text)
    end),
  })
end

function M.suggest(ctx, cb)
  local system = table.concat({
    "You are a low-latency code completion engine for Neovim (Blink).",
    "Return ONLY the text to insert at the cursor. No markdown fences, no commentary.",
    "Honor local naming/style; use filename and recent edits to stay consistent.",
    "Leverage JSON fields: before/after, imports (sampled), docs, siblings, lsp.diagnostics.",
    "If nothing sensible, return empty string.",
  }, "\n")

  post_anthropic({
    model = MODEL,
    max_tokens = MAX_TOKENS,
    temperature = TEMP_COMPLETION,
    system = system,
    messages = { { role = "user", content = vim.json.encode(ctx) } },
  }, cb)
end

function M.edit(text, prompt, context, cb)
  local system = table.concat({
    "You are a code assistant that edits text given project-wide context.",
    "Return ONLY the transformed code/text. If needed, include notes prefixed with 'COMMENT:' on a new line.",
    "No markdown fences or extra prose.",
  }, "\n")

  local user = string.format(
    "Context from other open files:\n%s\n\nMain file to modify:\n%s\n\nPrompt: %s\n",
    context,
    text,
    prompt
  )

  post_anthropic({
    model = MODEL,
    max_tokens = tonumber(vim.env.AI_ENGINE_MAX_TOKENS_EDIT or "4096"),
    temperature = TEMP_FORMAT,
    system = system,
    messages = { { role = "user", content = user } },
  }, function(ok, response)
    if not ok then
      return cb({ success = false, message = response })
    end
    local code, comments = response:match("^(.-)\nCOMMENT:(.+)$")
    code = (code or response):gsub("^```%w*\n", ""):gsub("\n```$", "")
    cb({ success = true, code = code, comments = comments })
  end)
end

return M
