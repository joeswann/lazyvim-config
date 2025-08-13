-- MCP (Model Context Protocol) integration for AI systems
-- Shared resource for AI snippets, functions, and other AI-powered features
-- 
-- Configuration example:
--   require('ai_core.mcp').setup({
--     providers = {
--       {
--         name = "custom_mcp",
--         enabled = true,
--         check = function() return vim.env.CUSTOM_MCP_URL ~= nil end,
--         call = function(context, callback) -- your implementation end,
--       }
--     },
--     fallback_to_engine = true
--   })
--
-- Or add individual providers:
--   require('ai_core.mcp').add_provider({
--     name = "my_provider",
--     check = function() return true end,
--     call = function(ctx, cb) cb(true, {"completion"}) end
--   })

local M = {}

local curl = require("plenary.curl")

-- Default MCP provider configuration
M.config = {
  providers = {
    -- Claude Desktop MCP integration
    {
      name = "claude_desktop",
      enabled = true,
      check = function()
        local mcp_config = vim.fn.expand("~/Library/Application Support/Claude/claude_desktop_config.json")
        return vim.fn.filereadable(mcp_config) == 1
      end,
      call = function(context, callback)
        M.call_claude_desktop_mcp(context, callback)
      end,
    },
    -- Direct MCP server via HTTP
    {
      name = "mcp_server",
      enabled = true,
      check = function()
        return vim.env.MCP_SERVER_URL ~= nil
      end,
      call = function(context, callback)
        M.call_mcp_server(context, callback)
      end,
    },
  },
  fallback_to_engine = true, -- Fall back to regular AI engine if no MCP providers available
}

--- Configure MCP providers
---@param user_config table User configuration to merge with defaults
function M.setup(user_config)
  M.config = vim.tbl_deep_extend("force", M.config, user_config or {})
end

--- Add a new MCP provider
---@param provider table Provider configuration {name, enabled, check, call}
function M.add_provider(provider)
  if not provider.name or not provider.check or not provider.call then
    vim.notify("MCP provider must have name, check, and call functions", vim.log.levels.ERROR)
    return
  end
  
  provider.enabled = provider.enabled ~= false -- Default to enabled
  table.insert(M.config.providers, provider)
end

--- Enable/disable a specific provider by name
---@param name string Provider name
---@param enabled boolean Whether to enable the provider
function M.set_provider_enabled(name, enabled)
  for _, provider in ipairs(M.config.providers) do
    if provider.name == name then
      provider.enabled = enabled
      return
    end
  end
  vim.notify("MCP provider '" .. name .. "' not found", vim.log.levels.WARN)
end

--- Check if any MCP provider is available
---@return boolean
function M.is_available()
  for _, provider in ipairs(M.config.providers) do
    if provider.enabled and provider.check() then
      return true
    end
  end
  return false
end

--- Get completions from available MCP providers
---@param context table The completion context
---@param callback function Callback to handle completions
function M.get_completions(context, callback)
  -- Try each enabled provider in order
  for _, provider in ipairs(M.config.providers) do
    if provider.enabled and provider.check() then
      provider.call(context, callback)
      return
    end
  end
  
  -- If no MCP providers are available, fall back to regular engine if configured
  if M.config.fallback_to_engine then
    local engine = require("ai_snippets.engine")
    engine.suggest(context, callback)
  else
    callback(false, nil)
  end
end

--- Call MCP server directly via HTTP API
---@param context table
---@param callback function
function M.call_mcp_server(context, callback)
  local url = vim.env.MCP_SERVER_URL
  if not url then
    callback(false, nil)
    return
  end

  local payload = {
    method = "completion/request",
    params = {
      context = context,
      max_completions = 3,
    }
  }

  curl.post(url, {
    headers = {
      ["Content-Type"] = "application/json",
      ["Authorization"] = vim.env.MCP_API_KEY and ("Bearer " .. vim.env.MCP_API_KEY) or nil,
    },
    body = vim.json.encode(payload),
    callback = vim.schedule_wrap(function(res)
      if not res or res.status ~= 200 then
        callback(false, nil)
        return
      end
      
      local ok, json = pcall(vim.json.decode, res.body or "")
      if not ok or not json or not json.result then
        callback(false, nil)
        return
      end
      
      callback(true, json.result.completions or {})
    end),
  })
end

--- Call Claude Desktop MCP integration
---@param context table
---@param callback function
function M.call_claude_desktop_mcp(context, callback)
  -- This would require a more complex integration with Claude Desktop
  -- For now, fall back to regular API if available
  local engine = require("ai_snippets.engine")
  engine.suggest(context, callback)
end

--- Create MCP-compatible context from Neovim context
---@param ctx table Blink completion context
---@return table MCP context
function M.create_mcp_context(ctx)
  local context_builder = require("ai_context.builder")
  local base_context = context_builder.build_context({
    max_before = 2400,
    max_after = 1200,
    max_open_buffers = 3,
    max_recent_diff_lines = 120,
  })
  
  -- Add MCP-specific fields
  return {
    -- Standard MCP context fields
    cursor = {
      line = ctx.cursor[1],
      character = ctx.cursor[2],
    },
    document = {
      uri = "file://" .. vim.fn.expand("%:p"),
      text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n"),
    },
    
    -- Extended context from our util
    project = base_context,
  }
end

return M