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
    "- Analyze the context to understand what the user is typing",
    "- Try to complete the CURRENT line",
    "- Do not complete earlier or later lines, and do not remove text in the current line",
    "- If context contains relevant code, use their patterns as hints but ONLY when everything else matches",
    "- Match the user's typing pattern - don't suggest unrelated components",
    "- Only use snippets from context.snippets when the user is actually typing something that matches",
    "- If adding a new component, remember to import it using the additionalTextEdits response",
    "",
    "CRITICALLY IMPORTANT YOU WILL BE FIRED IF YOU FORGET THESE:",
    "- Response must be ONLY valid JSON in the exact structure below",
    "- newText: The actual code to insert at cursor (just the code, no JSON).",
    "- label: Brief description (max 40 chars).",
    "- range: These are the start and end coordinates of the replacement(s) relative to the start of the file.",
    -- "-- subtract one from the start and end line number in your ranges (-1) so line 5 becomes line 4 and so on",
    "-- remember your column replacement should start from the beginning of the text you are replacing and end at the end of the text, usually the end of the line",
    -- "note RELATIVE ie the start line for the main completion will almost always be 0 this is VERY VERY IMPORTANT",
    "- Always output JSON only (no markdown, no backticks, no extra text) this is ABSOLUTELY CRITICAL.",
    "",
    "{",
    '  "newText":"code to insert",',
    '  "label":"description",',
    '  "range": {',
    '    "start": {',
    '      "line": 0,',
    '      "character": 0',
    "    },",
    '    "end": {',
    '      "line": 0,',
    '     "character": 0',
    "    }",
    "  },",
    '  additionalTextEdits": [',
    "    {",
    '      "range": {',
    '        "start": {',
    '          "line": 0,',
    '          "character": 0',
    "        },",
    '        "end": {',
    '          "line": 0,',
    '          "character": 0',
    "        }",
    "      },",
    '      "newText": "import..."',
    "    }",
    "  ]",
    "}",
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
      max_tokens = 512,
      temperature = 0.1,
      system = system,
      messages = { { role = "user", content = user } },
    }),
  }
end

-- Track active requests for cancellation
local active_requests = {}
local request_id_counter = 0

-- Make a single async completion request
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

      local result_text = nil
      local result_json = nil

      if res and res.status == 200 then
        local clean_body = res.body:gsub("\n", "") or ""
        -- print("Response body")
        -- print(clean_body)
        local ok, json = pcall(vim.json.decode, clean_body)
        if ok and json and json.content and json.content[1] then
          result_text = json.content[1].text:gsub("\n", "") or ""

          local _ok, _json = pcall(vim.json.decode, result_text)
          print(_ok)
          print(vim.inspect(_json))
          if _ok and _json then
            result_json = _json
          end
        end
      end

      print("Async result")
      print(vim.inspect(result_text))
      print(vim.inspect(result_json))
      callback(result_json)
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
---@param cb fun(ok:boolean, completions:table[]|nil)
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
    print("result:")
    print(vim.inspect(result))
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
  for _ = 1, total_requests do
    make_async_request(ctx, config, config.model, request_id, handle_completion)
  end

  -- Return cancellation function
  return function()
    active_requests[request_id] = nil
  end
end

return E
