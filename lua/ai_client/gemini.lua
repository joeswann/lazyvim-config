local GeminiClient = {}

local curl = require("plenary.curl")

function GeminiClient.new()
  local self = {}

  function self.get_config()
    print("[Gemini Client] Checking for GEMINI_API_KEY")
    if vim.env.GEMINI_API_KEY then
      local config = {
        provider = "gemini",
        api_key = vim.env.GEMINI_API_KEY,
        url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent",
        model = "gemini-2.5-flash",
      }
      print(string.format("[Gemini Client] Config created - model: %s", config.model))
      return config
    end
    print("[Gemini Client] No GEMINI_API_KEY found")
    return nil
  end

  function self.make_request(ctx, config, system_prompt, callback)
    print("[Gemini Client] Making request to Gemini API")
    local user_content = vim.json.encode(ctx)
    print(string.format("[Gemini Client] Context size: %d chars", #user_content))

    local payload = {
      url = config.url .. "?key=" .. config.api_key,
      headers = {
        ["content-type"] = "application/json",
      },
      body = vim.json.encode({
        system_instruction = {
          parts = {
            { text = system_prompt },
          },
        },
        contents = {
          {
            parts = {
              { text = user_content },
            },
          },
        },
        generationConfig = {
          temperature = 0.1,
          maxOutputTokens = 512,
        },
      }),
    }

    print(string.format("[Gemini Client] Payload size: %d chars", #payload.body))
    print(string.format("[Gemini Client] Making POST to: %s", config.url))

    curl.post(payload.url, {
      headers = payload.headers,
      body = payload.body,
      timeout = 2000,
      callback = vim.schedule_wrap(function(res)
        print(string.format("[Gemini Client] Response received - status: %s", res and res.status or "nil"))
        local response_text = nil

        if res and res.status == 200 then
          local clean_body = res.body:gsub("\n", "") or ""
          print(string.format("[Gemini Client] Response body size: %d chars", #clean_body))
          local ok, json = pcall(vim.json.decode, clean_body)
          if ok and json then
            print("[Gemini Client] JSON parsed successfully")
            if
              json.candidates
              and json.candidates[1]
              and json.candidates[1].content
              and json.candidates[1].content.parts
              and json.candidates[1].content.parts[1]
              and json.candidates[1].content.parts[1].text
            then
              response_text = json.candidates[1].content.parts[1].text
                :gsub("\n", "")
                :gsub("```json", "")
                :gsub("```", "") or ""
              print(string.format("[Gemini Client] Extracted text length: %d chars", #response_text))
              print(string.format("[Gemini Client] RAW RESPONSE TEXT: %s", response_text))
            else
              print("[Gemini Client] WARNING: No candidates[1].content.parts[1].text in response")
              print(string.format("[Gemini Client] Response structure: %s", vim.inspect(json)))
            end
          else
            print("[Gemini Client] ERROR: Failed to parse JSON response")
          end
        else
          print("[Gemini Client] ERROR: Non-200 status or no response")
          if res and res.body then
            print(string.format("[Gemini Client] Error body: %s", res.body))
          end
        end

        print(string.format("[Gemini Client] Calling callback with response: %s", response_text and "success" or "nil"))
        callback(response_text)
      end),
    })
  end

  return self
end

return GeminiClient
