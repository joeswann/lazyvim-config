local E = {}

local curl = require("plenary.curl")

local function anthropic_payload(ctx)
  local system = table.concat({
    "You are a low-latency code completion engine for Neovim (Blink).",
    "Return ONLY the text to insert at the cursor. No markdown fences or explanations.",
    "Use the JSON context (filename, before/after, open_buffers, recent_edits, project_root, docs, imports, siblings, lsp.diagnostics, ts_paths).",
    "Prefer short, syntactic completions that match local style and surrounding code.",
    "If no meaningful completion exists, return an empty string.",
  }, "\n")

  -- send the full context we built in util.build_context
  local user = vim.json.encode(ctx)

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
      if not res then
        vim.notify("curl: no response", vim.log.levels.ERROR)
        return cb(false)
      end
      if res.status ~= 200 then
        vim.notify(("curl HTTP %s: %s"):format(res.status, res.body or ""), vim.log.levels.ERROR)
        return cb(false)
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
