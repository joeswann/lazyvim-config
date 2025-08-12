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
  elseif vim.env.OPENROUTER_API_KEY then
    return {
      provider = "openrouter",
      api_key = vim.env.OPENROUTER_API_KEY,
      url = "https://openrouter.ai/api/v1/chat/completions",
      -- Use faster, cheaper models for quick completion
      models = {
        "anthropic/claude-3-haiku", -- Fastest Claude model
        "openai/gpt-3.5-turbo", -- Fast and cheap
        "meta-llama/llama-3.1-8b-instruct", -- Very fast open model
      },
    }
  end
  return nil
end

local function create_payload(ctx, config, model)
  local system = table.concat({
    "You are a fast code completion engine for Neovim.",
    "Generate ONE useful completion for the cursor position.",
    "Return ONLY the completion text. No JSON, markdown, or explanations.",
    "Focus on the most likely next code that fits the pattern.",
    "Keep it concise and relevant to the immediate context.",
  }, "\n")

  -- Balanced context size for speed vs usefulness
  local simplified_ctx = {
    language = ctx.language,
    filename = ctx.filename,
    before = ctx.before and ctx.before:sub(-1000) or "", -- Last 1000 chars
    after = ctx.after and ctx.after:sub(1, 400) or "", -- Next 400 chars
  }

  local user = vim.json.encode(simplified_ctx)

  if config.provider == "openrouter" then
    return {
      url = config.url,
      headers = {
        ["Authorization"] = "Bearer " .. config.api_key,
        ["Content-Type"] = "application/json",
        ["HTTP-Referer"] = "https://github.com/neovim/neovim",
        ["X-Title"] = "Neovim AI Snippets",
      },
      body = vim.json.encode({
        model = model or config.models[1],
        messages = {
          { role = "system", content = system },
          { role = "user", content = user },
        },
        max_tokens = 150, -- Good balance of speed and usefulness
        temperature = 0.1, -- Lower for consistency
        top_p = 0.8,
      }),
    }
  else -- anthropic
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
end

-- Track active requests for cancellation
local active_requests = {}
local request_id_counter = 0

--- Clean up a completion result
local function clean_completion(text)
  if not text or type(text) ~= "string" then
    return nil
  end
  local clean = text:gsub("^```%w*\n?", ""):gsub("\n?```%s*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
  return clean ~= "" and clean or nil
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
          if config.provider == "openrouter" then
            if json.choices and json.choices[1] and json.choices[1].message then
              result = json.choices[1].message.content or ""
            end
          else -- anthropic
            if json.content and json.content[1] then
              result = json.content[1].text or ""
            end
          end
        end
      end

      callback(clean_completion(result))
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
  if config.provider == "openrouter" and config.models then
    total_requests = math.min(3, #config.models)
    for i = 1, total_requests do
      make_async_request(ctx, config, config.models[i], request_id, handle_completion)
    end
  else
    total_requests = 2
    for i = 1, total_requests do
      make_async_request(ctx, config, config.model, request_id, handle_completion)
    end
  end

  -- Return cancellation function
  return function()
    active_requests[request_id] = nil
  end
end

return E
