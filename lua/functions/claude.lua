-- File: lua/functions/claude.lua
local curl = require("plenary.curl")
local utils = require("functions.utils")

local M = {}

-- Configuration
local config = {
  model = "claude-3-haiku-20240307",
  max_tokens = 4096,
  system_prompt = [[
You are a code assistant. For each input:
1. Use the provided context from other open files to inform your understanding
2. Process the main code/text according to the user's prompt
3. Return ONLY the processed code/text for the main file
4. If you have any comments or explanations, include them prefixed with "COMMENT:" on a new line after the code
Do not include any other conversation or markdown formatting.]],
}

local function make_claude_request(text, prompt, context, callback)
  local api_key = vim.env.ANTHROPIC_API_KEY
  if not api_key then
    return callback({
      success = false,
      message = "ANTHROPIC_API_KEY environment variable is not set",
    })
  end

  local url = "https://api.anthropic.com/v1/messages"
  local headers = {
    ["x-api-key"] = api_key,
    ["anthropic-version"] = "2023-06-01",
    ["content-type"] = "application/json",
  }

  -- Construct message with context
  local message = string.format(
    [[
Context from other open files:
%s

Main file to modify:
%s

Prompt: %s]],
    context,
    text,
    prompt
  )

  local data = {
    model = config.model,
    max_tokens = config.max_tokens,
    system = config.system_prompt,
    messages = {
      {
        role = "user",
        content = message,
      },
    },
  }

  curl.post(url, {
    body = vim.json.encode(data),
    headers = headers,
    callback = vim.schedule_wrap(function(response)
      if response.status ~= 200 then
        callback({
          success = false,
          message = "API request failed: " .. (response.body or "Unknown error"),
        })
        return
      end

      local ok, decoded = pcall(vim.json.decode, response.body)
      if not ok or not decoded then
        callback({
          success = false,
          message = "Failed to parse API response",
        })
        return
      end

      local response_text = decoded.content and decoded.content[1] and decoded.content[1].text
      if not response_text then
        callback({
          success = false,
          message = "No response text from Claude",
        })
        return
      end

      -- Split code and comments
      local code, comments = response_text:match("^(.-)\nCOMMENT:(.+)$")
      if not code then
        code = response_text
      end

      -- Clean up the code
      code = code:gsub("^```%w*\n", ""):gsub("\n```$", "")

      callback({
        success = true,
        code = code,
        comments = comments,
        message = "Processing complete",
      })
    end),
  })
end

function M.format_text(text, prompt, context, callback)
  if not text or text == "" then
    callback({
      success = false,
      message = "No text provided",
    })
    return
  end

  -- Implement retry logic
  local function try_request(attempt)
    if attempt > 3 then
      callback({
        success = false,
        message = "Failed after 3 attempts",
      })
      return
    end

    make_claude_request(text, prompt, context, function(result)
      if not result.success and attempt < 3 then
        vim.defer_fn(function()
          try_request(attempt + 1)
        end, 1000 * attempt)
      else
        callback(result)
      end
    end)
  end

  try_request(1)
end

return M
