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
    "You are a fast code completion engine for Neovim.",
    "You receive a context object with:",
    "- before: lines before cursor",
    "- current: text on current line up to cursor position",
    "- after: lines after cursor",
    "- snippets: array of {name, array_text} with snippet definitions",
    "- imports: already imported modules with their code samples",
    "- dependencies: available packages",
    "- github_similar: similar files from other projects with the same name",
    "",
    "COMPLETION RULES:",
    "1. Analyze the context to understand what the user is typing",
    "2. If github_similar contains files, use their patterns as hints but ONLY when relevant",
    "3. Only use snippets from context.snippets when the user is actually typing something that matches",
    "4. Focus on completing what the user is CURRENTLY typing, not random suggestions",
    "",
    "IMPORTANT RULES:",
    "- If user is typing 'HomeSec', complete it to 'HomeSections' or similar, NOT 'SanityImage'",
    "- Match the user's typing pattern - don't suggest unrelated components",
    "- Only suggest from context.snippets if it matches what's being typed",
    "",
    "Response must be ONLY valid JSON in this exact format:",
    '{"completion": "code to insert", "label": "description", "range": {...}, "additionalTextEdits": [...]}',
    "- completion: The actual code to insert at cursor (just the code, no JSON)",
    "- label: Brief description (max 40 chars)",
    "- range: {start_line: 0, start_col: 0, end_line: 0, end_col: N}",
    "- additionalTextEdits: (optional) Array of edits to add imports",
    "",
    "CRITICAL: Return ONLY the JSON object, no markdown, no backticks, no explanation.",
    "The 'completion' field must contain ONLY the code to insert, not JSON.",
  }, "\n")

  local user = vim.json.encode(ctx)

  return {
    url = config.url,
    headers = {
      ["x-api-key"] = config.api_key,
      ["anthropic-version"] = "2023-06-01",
      ["content-type"] = "application/json",
    },
    body = vim.json.encode({
      model = config.model,
      max_tokens = 150,
      temperature = 0.1,
      system = system,
      messages = { { role = "user", content = user } },
    }),
  }
end
-- Track active requests for cancellation
local active_requests = {}
local request_id_counter = 0

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
    if result.completion and result.label and result.range then
      return {
        completion = result.completion,
        label = result.label,
        range = result.range,
        additionalTextEdits = result.additionalTextEdits,
      }
    end
  end

  -- IMPORTANT: Don't return raw JSON as fallback
  -- Only return plain text if it doesn't look like JSON
  if not clean_text:match("^%s*{") and not clean_text:match("completion") then
    return {
      completion = clean_text,
      label = clean_text:gsub("\n", "↵"):sub(1, 40) .. (clean_text:len() > 40 and "..." or ""),
      range = { start_line = 0, start_col = 0, end_line = 0, end_col = 0 },
    }
  end

  -- If it looks like JSON but failed to parse, return nil
  return nil
end --- Make a single async completion request
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
