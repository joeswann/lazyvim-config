-- TypeScript/JavaScript context patterns and dependency resolution
local M = {}

-- File extensions for TypeScript/JavaScript projects
M.extensions = { ".tsx", ".ts", ".jsx", ".js", ".d.ts", ".json", ".css", ".module.css" }

-- Dependency files specific to JavaScript/TypeScript projects
M.dependency_files = {
  "package.json",
  "package-lock.json", 
  "yarn.lock",
  "pnpm-lock.yaml",
  "tsconfig.json",
  "jsconfig.json",
  ".eslintrc.json",
  ".eslintrc.js",
  "vite.config.ts",
  "vite.config.js",
  "next.config.js",
  "next.config.ts",
  "webpack.config.js",
  "rollup.config.js",
  "babel.config.js",
  ".babelrc",
}

-- Import patterns for JavaScript/TypeScript
M.import_patterns = {
  "import%s+.-from%s+['\"](.-)['\"]",          -- import ... from 'module'
  "import%s*%(%s*['\"](.-)['\"]%s*%)",         -- import('module')
  "require%s*%(%s*['\"](.-)['\"]%s*%)",        -- require('module')
  "from%s+['\"](.-)['\"]%s+import",            -- from 'module' import ...
}

-- TypeScript config file patterns
M.config_patterns = {
  tsconfig = { "tsconfig.json", "jsconfig.json" },
  eslint = { ".eslintrc.json", ".eslintrc.js", ".eslintrc.yml" },
  prettier = { ".prettierrc", ".prettierrc.json", ".prettierrc.js" },
}

--- Load TypeScript aliases from config files
---@param root string Project root directory
---@return table alias_map, string|nil base_url
function M.load_aliases(root)
  local join = function(a, b) return (a:gsub("/+$", "")) .. "/" .. (b:gsub("^/+", "")) end
  local fs_exists = function(p) return p and vim.loop.fs_stat(p) ~= nil end
  local simplify = function(p) return vim.fn.simplify(p) end
  
  local files = { "tsconfig.json", "jsconfig.json" }
  local alias = {}
  local baseUrlAbs = nil

  for _, name in ipairs(files) do
    local p = join(root, name)
    if fs_exists(p) then
      local ok, txt = pcall(vim.fn.readfile, p)
      if ok and txt and #txt > 0 then
        local ok2, cfg = pcall(vim.json.decode, table.concat(txt, "\n"))
        if ok2 and cfg and cfg.compilerOptions then
          local co = cfg.compilerOptions
          if co.baseUrl and type(co.baseUrl) == "string" then
            baseUrlAbs = simplify(join(root, co.baseUrl))
          end
          if co.paths and type(co.paths) == "table" then
            for k, arr in pairs(co.paths) do
              local prefix = k:gsub("/%*$", "")
              local dest = (type(arr) == "table" and arr[1]) or arr
              if type(dest) == "string" then
                dest = dest:gsub("/%*$", "")
                alias[prefix] = simplify(join(baseUrlAbs or root, dest))
              end
            end
          end
        end
      end
    end
  end

  -- Common custom alias: "~" → src
  if not alias["~"] and fs_exists(join(root, "src")) then
    alias["~"] = join(root, "src")
  end

  return alias, baseUrlAbs
end

--- Resolve import path to file system path
---@param raw string Raw import path
---@param file_dir string Directory of the current file
---@param root string Project root
---@param alias table Alias mappings
---@param base_url string|nil Base URL for resolution
---@return string|nil Resolved file path
function M.resolve_import(raw, file_dir, root, alias, base_url)
  local join = function(a, b) return (a:gsub("/+$", "")) .. "/" .. (b:gsub("^/+", "")) end
  local fs_exists = function(p) return p and vim.loop.fs_stat(p) ~= nil end
  local simplify = function(p) return vim.fn.simplify(p) end
  
  local function try_resolve(base, frag)
    local candidates = {}
    if frag:match("%.%w+$") then
      table.insert(candidates, frag)
    else
      for _, e in ipairs(M.extensions) do
        table.insert(candidates, frag .. e)
      end
      for _, e in ipairs(M.extensions) do
        table.insert(candidates, frag .. "/index" .. e)
      end
    end
    for _, c in ipairs(candidates) do
      local p = simplify(join(base, c))
      if fs_exists(p) then
        return p
      end
    end
    return nil
  end

  -- Relative imports
  if raw:match("^%.") then
    return try_resolve(file_dir, raw)
  end
  
  -- Absolute imports
  if raw:match("^/") then
    return try_resolve(root, raw)
  end
  
  -- Alias prefix resolution
  for pref, target in pairs(alias or {}) do
    if raw == pref or raw:sub(1, #pref + 1) == (pref .. "/") then
      local rest = raw:sub(#pref + 2)
      return try_resolve(target, rest)
    end
  end
  
  -- Base URL resolution
  if base_url then
    local p = try_resolve(base_url, raw)
    if p then return p end
  end
  
  return nil
end

--- Parse imports from file lines
---@param lines table Array of file lines
---@return table Array of import paths
function M.parse_imports(lines)
  local imports = {}
  for _, l in ipairs(lines) do
    for _, pattern in ipairs(M.import_patterns) do
      local m = l:match(pattern)
      if m and not m:match("^node:") and not m:match("^https?://") then
        table.insert(imports, m)
        break -- Found match, don't check other patterns for this line
      end
    end
  end
  return imports
end

--- Get TypeScript/JavaScript specific context
---@param base_context table Base context from builder
---@param opts table Options
---@return table Enhanced context with TS/JS specific data
function M.enhance_context(base_context, opts)
  opts = opts or {}
  local root = base_context.project_root
  local file = base_context.filepath
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  
  -- Load TypeScript configuration
  local alias, baseUrlAbs = M.load_aliases(root)
  local bufdir = vim.fn.fnamemodify(file, ":p:h")
  
  -- Collect import samples
  local imports = M.parse_imports(lines)
  local import_samples = {}
  local seen = {}
  
  for _, raw in ipairs(imports) do
    if not seen[raw] then
      seen[raw] = true
      local resolved = M.resolve_import(raw, bufdir, root, alias, baseUrlAbs)
      if resolved and vim.loop.fs_stat(resolved) and not resolved:match("/node_modules/") then
        local f = io.open(resolved, "r")
        if f then
          local content = f:read("*a") or ""
          f:close()
          if content ~= "" then
            local sample = content:sub(1, opts.max_import_chars or 1500)
            table.insert(import_samples, { 
              raw = raw, 
              path = vim.fn.fnamemodify(resolved, ":~:."), 
              sample = sample 
            })
            if opts.max_imports and #import_samples >= opts.max_imports then
              break
            end
          end
        end
      end
    end
  end
  
  -- Add TypeScript-specific context
  base_context.imports = import_samples
  base_context.ts_config = {
    alias = alias,
    baseUrl = baseUrlAbs,
  }
  
  return base_context
end

return M