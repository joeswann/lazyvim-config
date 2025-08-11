local E = {}

local curl = require("plenary.curl")

local function anthropic_payload(ctx)
  local system = table.concat({
    "You are a low-latency code completion engine for Neovim (Blink).",
    "Return ONLY the text to insert at the cursor. No markdown fences, no explanations.",
    "Prefer short, syntactic completions that match surrounding style.",
    "Use the filename and recent edits to keep names and patterns consistent.",
    "If no meaningful completion exists, return an empty string.",
  }, "\n")

  local user = vim.json.encode({
    language = ctx.language,
    filename = ctx.filename,
    filepath = ctx.filepath,
    cursor = ctx.cursor,
    before = ctx.before,
    after = ctx.after,
    recent_edits = ctx.recent_edits,
    open_buffers = ctx.open_buffers,
  })

  return {
    url = "https://api.anthropic.com/v1/messages",
    headers = {
      ["x-api-key"] = vim.env.ANTHROPIC_API_KEY,
      ["anthropic-version"] = "2023-06-01",
      ["content-type"] = "application/json",
    },
    body = vim.json.encode({
      model = "claude-3-5-sonnet-20240620", -- good latency/quality tradeoff
      max_tokens = 120,
      temperature = 0.2,
      system = system,
      messages = { { role = "user", content = user } },
    }),
  }
end

--- Suggest a single completion text
---@param ctx table
---@param cb fun(ok:boolean, text:string|nil)
function E.suggest(ctx, cb)
  if not vim.env.ANTHROPIC_API_KEY then
    return cb(false, nil)
  end

  local req = anthropic_payload(ctx)
  curl.post(req.url, {
    headers = req.headers,
    body = req.body,
    callback = vim.schedule_wrap(function(res)
      if not res or res.status ~= 200 then
        return cb(false, nil)
      end
      local ok, json = pcall(vim.json.decode, res.body or "")
      if not ok or not json or not json.content or not json.content[1] then
        return cb(false, nil)
      end
      local text = json.content[1].text or ""
      -- Hard strip any accidental markdown/code fences
      text = text:gsub("^```%w*\n", ""):gsub("\n```%s*$", "")
      cb(true, text)
    end),
  })
end

return E
