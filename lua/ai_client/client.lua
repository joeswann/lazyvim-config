local Client = {}

local ClaudeClient = require("ai_client.claude")
local GeminiClient = require("ai_client.gemini")

function Client.create_client(provider)
  print(string.format("[AI Client] Creating client for provider: %s", provider))
  
  if provider == "claude" or provider == "anthropic" then
    local client = ClaudeClient.new()
    print("[AI Client] Claude client created successfully")
    return client
  elseif provider == "gemini" or provider == "google" then
    local client = GeminiClient.new()
    print("[AI Client] Gemini client created successfully")
    return client
  end
  
  local error_msg = "Unsupported provider: " .. tostring(provider)
  print("[AI Client] ERROR: " .. error_msg)
  error(error_msg)
end

function Client.get_default_client()
  local provider = vim.g.ai_provider or "auto"
  print(string.format("[AI Client] Provider setting: %s", provider))
  
  print(string.format("[AI Client] Available API keys - ANTHROPIC: %s, GEMINI: %s", 
    vim.env.ANTHROPIC_API_KEY and "yes" or "no",
    vim.env.GEMINI_API_KEY and "yes" or "no"))

  if provider == "claude" or provider == "anthropic" then
    if vim.env.ANTHROPIC_API_KEY then
      print("[AI Client] Using configured Claude provider")
      return Client.create_client("claude")
    else
      print("[AI Client] WARNING: Claude provider configured but ANTHROPIC_API_KEY not found")
    end
  elseif provider == "gemini" or provider == "google" then
    if vim.env.GEMINI_API_KEY then
      print("[AI Client] Using configured Gemini provider")
      return Client.create_client("gemini")
    else
      print("[AI Client] WARNING: Gemini provider configured but GEMINI_API_KEY not found")
    end
  elseif provider == "auto" then
    print("[AI Client] Auto-selecting provider based on available API keys")
    -- Auto-select based on available API keys (prioritize Claude)
    if vim.env.ANTHROPIC_API_KEY then
      print("[AI Client] Auto-selected Claude (ANTHROPIC_API_KEY available)")
      return Client.create_client("claude")
    elseif vim.env.GEMINI_API_KEY then
      print("[AI Client] Auto-selected Gemini (GEMINI_API_KEY available)")
      return Client.create_client("gemini")
    else
      print("[AI Client] WARNING: No API keys found for auto-selection")
    end
  end

  print("[AI Client] ERROR: No client could be created")
  return nil
end

return Client
