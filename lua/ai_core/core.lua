-- File: lua/ai_core/core.lua
local M = {}
local curl = require("plenary.curl")

-- Config via env; sensible defaults
local MODEL = vim.env.AI_ENGINE_MODEL or "claude-sonnet-4-20250514"
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
    "You are a fast code completion engine for Neovim with snippet support.",
    "You will receive context with 'before' (lines before cursor), 'current' (text on current line up to cursor), and 'after' (lines after cursor).",
    "Generate ONE useful completion and respond with JSON in this EXACT format:",
    '{"text": "completion text here", "label": "short description", "range": {"start_line": 0, "start_col": 0, "end_line": 0, "end_col": 5}}',
    "- text: The completion text with snippet placeholders like ${1:param}, ${2:value}",
    "- label: A short, descriptive label for what this completion does",
    "- range: The text range to replace (0-based line/column numbers relative to cursor position)",
    "  - start_line/start_col: How many lines/cols before cursor to start replacing (usually 0,0 for cursor position)",
    "  - end_line/end_col: How many lines/cols after cursor to end replacing",
    "Focus on the most likely next code that fits the pattern.",
    "Use available dependencies and imports from the context.",
    "Return ONLY valid JSON, no markdown or explanations.",
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
