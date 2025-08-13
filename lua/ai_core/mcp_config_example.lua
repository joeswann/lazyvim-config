-- Example MCP provider configuration
-- Copy this to your init.lua or a separate config file and customize as needed

local mcp = require("ai_core.mcp")

-- Configure existing providers and add custom ones
mcp.setup({
  providers = {
    -- Disable Claude Desktop MCP if you don't want it
    {
      name = "claude_desktop",
      enabled = false, -- Set to false to disable
    },
    
    -- Example: Custom local MCP server
    {
      name = "local_server",
      enabled = true,
      check = function()
        return vim.env.LOCAL_MCP_PORT ~= nil
      end,
      call = function(context, callback)
        local curl = require("plenary.curl")
        curl.post("http://localhost:" .. vim.env.LOCAL_MCP_PORT .. "/complete", {
          headers = { ["Content-Type"] = "application/json" },
          body = vim.json.encode({ context = context }),
          callback = function(res)
            if res.status == 200 then
              local ok, json = pcall(vim.json.decode, res.body)
              if ok and json.completions then
                callback(true, json.completions)
              else
                callback(false, nil)
              end
            else
              callback(false, nil)
            end
          end
        })
      end,
    },
    
    -- Example: OpenAI-compatible API as MCP provider
    {
      name = "openai_mcp",
      enabled = false, -- Enable if you want to use this
      check = function()
        return vim.env.OPENAI_API_KEY ~= nil
      end,
      call = function(context, callback)
        local curl = require("plenary.curl")
        curl.post("https://api.openai.com/v1/chat/completions", {
          headers = {
            ["Authorization"] = "Bearer " .. vim.env.OPENAI_API_KEY,
            ["Content-Type"] = "application/json",
          },
          body = vim.json.encode({
            model = "gpt-4",
            messages = {
              {
                role = "system",
                content = "You are a code completion engine. Return only the completion text."
              },
              {
                role = "user", 
                content = vim.json.encode(context)
              }
            },
            max_tokens = 150,
            temperature = 0.1,
          }),
          callback = function(res)
            if res.status == 200 then
              local ok, json = pcall(vim.json.decode, res.body)
              if ok and json.choices and json.choices[1] then
                local completion = json.choices[1].message.content
                callback(true, {completion})
              else
                callback(false, nil)
              end
            else
              callback(false, nil)
            end
          end
        })
      end,
    },
  },
  fallback_to_engine = true, -- Keep fallback enabled
})

-- Or add providers individually:
-- mcp.add_provider({
--   name = "my_custom_provider",
--   enabled = true,
--   check = function() return true end, -- Always available
--   call = function(context, callback)
--     -- Your custom logic here
--     callback(true, {"custom completion"})
--   end
-- })

-- Enable/disable providers dynamically:
-- mcp.set_provider_enabled("claude_desktop", false)
-- mcp.set_provider_enabled("my_custom_provider", true)