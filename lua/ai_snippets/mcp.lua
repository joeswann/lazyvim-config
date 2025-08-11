-- MCP (Model Context Protocol) integration for AI snippets
local M = {}

local curl = require("plenary.curl")

--- Check if MCP server is available
---@return boolean
function M.is_available()
  -- Check if Claude Desktop with MCP is available
  local mcp_config = vim.fn.expand("~/Library/Application Support/Claude/claude_desktop_config.json")
  return vim.fn.filereadable(mcp_config) == 1 or vim.env.MCP_SERVER_URL ~= nil
end

--- Get completions from MCP server
---@param context table The completion context
---@param callback function Callback to handle completions
function M.get_completions(context, callback)
  -- If MCP_SERVER_URL is set, use direct HTTP API
  if vim.env.MCP_SERVER_URL then
    M.call_mcp_server(context, callback)
    return
  end
  
  -- Otherwise, try to use Claude Desktop MCP integration
  M.call_claude_desktop_mcp(context, callback)
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
  local util = require("ai_snippets.util")
  local base_context = util.build_context({
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