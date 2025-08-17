local ClaudeClient = {}

local curl = require("plenary.curl")

function ClaudeClient.new()
  local self = {}
  
  function self.get_config()
    print("[Claude Client] Checking for ANTHROPIC_API_KEY")
    if vim.env.ANTHROPIC_API_KEY then
      local config = {
        provider = "anthropic",
        api_key = vim.env.ANTHROPIC_API_KEY,
        url = "https://api.anthropic.com/v1/messages",
        model = "claude-3-haiku-20240307", -- Use Haiku for speed
      }
      print(string.format("[Claude Client] Config created - model: %s", config.model))
      return config
    end
    print("[Claude Client] No ANTHROPIC_API_KEY found")
    return nil
  end

  function self.make_request(ctx, config, system_prompt, callback)
    print("[Claude Client] Making request to Claude API")
    local user = vim.json.encode(ctx)
    print(string.format("[Claude Client] Context size: %d chars", #user))

    local payload = {
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
        system = system_prompt,
        messages = { { role = "user", content = user } },
      }),
    }
    
    print(string.format("[Claude Client] Payload size: %d chars", #payload.body))
    print(string.format("[Claude Client] Making POST to: %s", config.url))

    curl.post(payload.url, {
      headers = payload.headers,
      body = payload.body,
      timeout = 2000,
      callback = vim.schedule_wrap(function(res)
        print(string.format("[Claude Client] Response received - status: %s", res and res.status or "nil"))
        local response_text = nil

        if res and res.status == 200 then
          local clean_body = res.body:gsub("\n", "") or ""
          print(string.format("[Claude Client] Response body size: %d chars", #clean_body))
          local ok, json = pcall(vim.json.decode, clean_body)
          if ok and json then
            print(string.format("[Claude Client] JSON parsed successfully"))
            if json.content and json.content[1] and json.content[1].text then
              response_text = json.content[1].text:gsub("\n", "") or ""
              print(string.format("[Claude Client] Extracted text length: %d chars", #response_text))
              print(string.format("[Claude Client] RAW RESPONSE TEXT: %s", response_text))
            else
              print("[Claude Client] WARNING: No content[1].text in response")
              print(string.format("[Claude Client] Response structure: %s", vim.inspect(json)))
            end
          else
            print("[Claude Client] ERROR: Failed to parse JSON response")
          end
        else
          print(string.format("[Claude Client] ERROR: Non-200 status or no response"))
          if res and res.body then
            print(string.format("[Claude Client] Error body: %s", res.body))
          end
        end

        print(string.format("[Claude Client] Calling callback with response: %s", response_text and "success" or "nil"))
        callback(response_text)
      end),
    })
  end

  return self
end

return ClaudeClient