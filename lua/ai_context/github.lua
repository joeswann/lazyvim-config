-- lua/ai_context/github.lua
local M = {}
local curl = require("plenary.curl")

-- Cache for GitHub searches to avoid rate limiting
local cache = {}
local cache_ttl = 600 -- 10 minutes (increased from 5)
local pending_fetches = {} -- Track ongoing fetches to avoid duplicates

local function get_github_token()
  return vim.env.GITHUB_TOKEN or vim.env.GH_TOKEN
end

--- Decode base64 string
---@param data string Base64 encoded string
---@return string|nil Decoded string
local function decode_base64(data)
  if not data then
    return nil
  end

  -- Remove whitespace and newlines
  data = data:gsub("%s+", "")

  -- Use vim.fn.system to decode base64
  local decoded = vim.fn.system("echo '" .. data .. "' | base64 -d 2>/dev/null")

  -- Check if decoding was successful
  if vim.v.shell_error ~= 0 then
    -- Try alternative base64 command (for macOS)
    decoded = vim.fn.system("echo '" .. data .. "' | base64 -D 2>/dev/null")
    if vim.v.shell_error ~= 0 then
      return nil
    end
  end

  return decoded
end

--- Search GitHub for files with the same name (optimized version)
---@param filename string The filename to search for
---@param opts table Options including max_results, exclude_repos
---@return table Array of {repo, path, content} or empty table
function M.search_similar_files(filename, opts)
  opts = opts or {}
  local max_results = opts.max_results or 2 -- Reduced from 3
  local exclude_repos = opts.exclude_repos or {}

  -- Quick return for non-component files
  if
    not filename:match("^[A-Z].*%.tsx?$")
    and not filename:match("^[A-Z].*%.jsx?$")
    and not filename:match("%.py$")
    and not filename:match("%.go$")
  then
    return {}
  end

  -- Check cache
  local cache_key = filename .. vim.json.encode(opts)
  local cached = cache[cache_key]
  if cached and (os.time() - cached.time) < cache_ttl then
    return cached.data or {}
  end

  local token = get_github_token()
  if not token then
    -- Cache empty result to avoid repeated attempts
    cache[cache_key] = { time = os.time(), data = {} }
    return {}
  end

  -- Get GitHub username (with caching)
  local username = vim.env.GITHUB_USER
  if not username then
    username = M.get_github_user(token)
    if not username then
      cache[cache_key] = { time = os.time(), data = {} }
      return {}
    end
  end

  -- Search query: filename in user's repos
  local query = string.format('filename:"%s" user:%s', filename, username)

  local response = curl.get("https://api.github.com/search/code", {
    headers = {
      ["Authorization"] = "Bearer " .. token,
      ["Accept"] = "application/vnd.github.v3+json",
      ["User-Agent"] = "Neovim-AI-Context",
    },
    query = {
      q = query,
      per_page = tostring(max_results * 2),
    },
    timeout = 2000, -- Reduced from 5000
  })

  print(vim.inspect(response))

  if not response or response.status ~= 200 then
    -- Cache failed result
    cache[cache_key] = { time = os.time(), data = {} }
    return {}
  end

  local ok, data = pcall(vim.json.decode, response.body)
  if not ok or not data or not data.items then
    cache[cache_key] = { time = os.time(), data = {} }
    return {}
  end

  -- Collect items to fetch
  local to_fetch = {}
  local seen_repos = {}

  for _, item in ipairs(data.items) do
    if item and item.repository then
      local repo_name = item.repository.name

      if not seen_repos[repo_name] and not vim.tbl_contains(exclude_repos, repo_name) then
        seen_repos[repo_name] = true
        table.insert(to_fetch, {
          repo = repo_name,
          path = item.path,
          url = item.url,
          html_url = item.html_url,
        })

        if #to_fetch >= max_results then
          break
        end
      end
    end
  end

  -- Fetch content with shorter timeout
  local results = {}
  for _, item in ipairs(to_fetch) do
    local content = M.fetch_file_content_fast(item.url, token)
    if content then
      table.insert(results, {
        repo = item.repo,
        path = item.path,
        content = content,
        html_url = item.html_url,
      })
    end
  end

  -- Cache the results
  cache[cache_key] = {
    time = os.time(),
    data = results,
  }

  return results
end

--- Fetch file content from GitHub with reduced timeout
---@param api_url string GitHub API URL for the file
---@param token string GitHub token
---@return string|nil File content
function M.fetch_file_content_fast(api_url, token)
  if not api_url or not token then
    return nil
  end

  local response = curl.get(api_url, {
    headers = {
      ["Authorization"] = "Bearer " .. token,
      ["Accept"] = "application/vnd.github.v3+json",
      ["User-Agent"] = "Neovim-AI-Context",
    },
    timeout = 1000, -- Reduced from 3000
  })

  if not response or response.status ~= 200 then
    return nil
  end

  local ok, data = pcall(vim.json.decode, response.body)
  if not ok or not data or not data.content then
    return nil
  end

  -- GitHub returns base64 encoded content
  local decoded = decode_base64(data.content)

  -- Limit content size for performance
  if decoded and #decoded > 5000 then
    decoded = decoded:sub(1, 5000)
  end

  return decoded
end

--- Get GitHub username from token (with caching)
---@param token string
---@return string|nil
function M.get_github_user(token)
  if not token then
    return nil
  end

  -- Check if already cached in env
  if vim.env.GITHUB_USER then
    return vim.env.GITHUB_USER
  end

  local response = curl.get("https://api.github.com/user", {
    headers = {
      ["Authorization"] = "Bearer " .. token,
      ["Accept"] = "application/vnd.github.v3+json",
      ["User-Agent"] = "Neovim-AI-Context",
    },
    timeout = 1500, -- Reduced from 3000
  })

  if not response or response.status ~= 200 then
    return nil
  end

  local ok, data = pcall(vim.json.decode, response.body)
  if ok and data and data.login then
    -- Cache the username in env for future use
    vim.env.GITHUB_USER = data.login
    return data.login
  end

  return nil
end

--- Clear cache for a specific file or all files
---@param filename string|nil
function M.clear_cache(filename)
  if filename then
    for key, _ in pairs(cache) do
      if key:match(filename) then
        cache[key] = nil
      end
    end
  else
    cache = {}
  end
end

--- Check if GitHub search is available
---@return boolean
function M.is_available()
  return get_github_token() ~= nil
end

return M
