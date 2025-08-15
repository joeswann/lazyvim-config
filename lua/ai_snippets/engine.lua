local E = {}

local curl = require("plenary.curl")

local function get_api_config()
  if vim.env.ANTHROPIC_API_KEY then
    return {
      provider = "anthropic",
      api_key = vim.env.ANTHROPIC_API_KEY,
      url = "https://api.anthropic.com/v1/messages",
      model = "claude-3-haiku-20240307", -- Use Haiku for speed
    }
  end
  return nil
end

local function create_payload(ctx, config, model)
  local system = table.concat({
    "You are a fast code completion engine for Neovim with snippet support.",
    "You will receive context including details such as 'before' (lines before cursor), 'current' (text on current line up to cursor), and 'after' (lines after cursor).",
    "Generate ONE useful completion and respond with JSON in this EXACT format:",
    '{"text": "completion text here", "label": "short description", "range": {"start_line": 0, "start_col": 0, "end_line": 0, "end_col": 5}}',
    "- text: The completion text",
    "- label: A short, descriptive label for what this completion does",
    "- range: The text range to replace (0-based line/column numbers relative to cursor position)",
    "  - start_line/start_col: How many lines/cols before cursor to start replacing (usually 0,0 for cursor position)",
    "  - end_line/end_col: How many lines/cols after cursor to end replacing",
    "Focus on the most likely next code that fits the pattern.",
    "Use available dependencies and imports from the context.",
    "Return ONLY valid JSON, no markdown or explanations.",
  }, "\n")

  -- Use the new context structure
  local simplified_ctx = {
    language = ctx.language,
    filename = ctx.filename,
    before = ctx.before and ctx.before:sub(-1000) or "", -- Last 1000 chars of before
    current = ctx.current or "", -- Current line text up to cursor
    after = ctx.after and ctx.after:sub(1, 400) or "", -- Next 400 chars of after
  }

  local user = vim.json.encode(simplified_ctx)

  return {
    url = config.url,
    headers = {
      ["x-api-key"] = config.api_key,
      ["anthropic-version"] = "2023-06-01",
      ["content-type"] = "application/json",
    },
    body = vim.json.encode({
      model = config.model,
      max_tokens = 150, -- Good balance of speed and usefulness
      temperature = 0.1,
      system = system,
      messages = { { role = "user", content = user } },
    }),
  }
end

-- Track active requests for cancellation
local active_requests = {}
local request_id_counter = 0

--- Parse and clean up a completion result from JSON
local function parse_completion(text)
  if not text or type(text) ~= "string" then
    return nil
  end

  -- Clean markdown if present
  local clean_text = text:gsub("^```json\n?", ""):gsub("\n?```%s*$", ""):gsub("^%s+", ""):gsub("%s+$", "")

  -- Try to parse as JSON
  local ok, result = pcall(vim.json.decode, clean_text)
  if ok and result and type(result) == "table" then
    -- Validate required fields
    if result.text and result.label and result.range then
      return {
        text = result.text,
        label = result.label,
        range = result.range,
      }
    end
  end

  -- Fallback: treat as plain text completion
  if clean_text ~= "" then
    return {
      text = clean_text,
      label = clean_text:gsub("\n", "↵"):sub(1, 40) .. (clean_text:len() > 40 and "..." or ""),
      range = { start_line = 0, start_col = 0, end_line = 0, end_col = 0 },
    }
  end

  return nil
end

--- Make a single async completion request
local function make_async_request(ctx, config, model, request_id, callback)
  local req = create_payload(ctx, config, model)

  curl.post(req.url, {
    headers = req.headers,
    body = req.body,
    timeout = 2000,
    callback = vim.schedule_wrap(function(res)
      -- Check if request was cancelled
      if not active_requests[request_id] then
        return
      end

      local result = nil
      if res and res.status == 200 then
        local ok, json = pcall(vim.json.decode, res.body or "")
        if ok and json then
          if json.content and json.content[1] then
            result = json.content[1].text or ""
          end
        end
      end

      callback(parse_completion(result))
    end),
  })
end

--- Cancel all active requests
function E.cancel_requests()
  for id, _ in pairs(active_requests) do
    active_requests[id] = nil
  end
end

--- Suggest multiple completion texts using parallel async requests
---@param ctx table
---@param cb fun(ok:boolean, completions:string[]|nil)
function E.suggest(ctx, cb)
  local config = get_api_config()
  if not config then
    return cb(false, nil)
  end

  -- Cancel any existing requests
  E.cancel_requests()

  -- Generate new request ID
  request_id_counter = request_id_counter + 1
  local request_id = request_id_counter
  active_requests[request_id] = true

  -- Track completions from parallel requests
  local completions = {}
  local completed_requests = 0
  local total_requests = 0

  local function handle_completion(result)
    completed_requests = completed_requests + 1

    if result then
      table.insert(completions, result)
    end

    -- Return results as soon as we have at least one, or all requests complete
    if (#completions > 0 and completed_requests >= 1) or completed_requests >= total_requests then
      -- Clean up
      active_requests[request_id] = nil

      if #completions > 0 then
        cb(true, completions)
      else
        cb(false, nil)
      end
    end
  end

  -- Start parallel requests
  total_requests = 2
  for i = 1, total_requests do
    make_async_request(ctx, config, config.model, request_id, handle_completion)
  end

  -- Return cancellation function
  return function()
    active_requests[request_id] = nil
  end
end

return E
