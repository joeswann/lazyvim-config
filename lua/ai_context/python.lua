-- Python context patterns and dependency resolution
local M = {}

-- File extensions for Python projects
M.extensions = { ".py", ".pyx", ".pyi", ".pyw" }

-- Dependency files specific to Python projects
M.dependency_files = {
  "requirements.txt",
  "requirements-dev.txt",
  "requirements-test.txt",
  "pyproject.toml",
  "setup.py",
  "setup.cfg",
  "Pipfile",
  "Pipfile.lock",
  "poetry.lock",
  "conda.yaml",
  "environment.yml",
  "tox.ini",
  "pytest.ini",
  ".python-version",
}

-- Import patterns for Python
M.import_patterns = {
  "^%s*import%s+([%w_.]+)",                    -- import module
  "^%s*from%s+([%w_.]+)%s+import",             -- from module import ...
  "^%s*from%s+%.([%w_.]+)%s+import",           -- from .module import ... (relative)
}

-- Python config file patterns
M.config_patterns = {
  project = { "pyproject.toml", "setup.py", "setup.cfg" },
  testing = { "pytest.ini", "tox.ini", ".coveragerc" },
  linting = { ".flake8", "mypy.ini", ".pylintrc", "pyproject.toml" },
  formatting = { ".black", "pyproject.toml" },
}

--- Parse Python imports from file lines
---@param lines table Array of file lines
---@return table Array of import module names
function M.parse_imports(lines)
  local imports = {}
  for _, l in ipairs(lines) do
    for _, pattern in ipairs(M.import_patterns) do
      local m = l:match(pattern)
      if m then
        -- Skip standard library and built-in modules (basic list)
        local stdlib_modules = {
          "os", "sys", "re", "json", "datetime", "time", "random", "math",
          "collections", "itertools", "functools", "typing", "pathlib",
          "urllib", "http", "socket", "threading", "multiprocessing"
        }
        local is_stdlib = false
        for _, stdlib in ipairs(stdlib_modules) do
          if m == stdlib or m:match("^" .. stdlib .. "%.") then
            is_stdlib = true
            break
          end
        end
        if not is_stdlib then
          table.insert(imports, m)
        end
        break
      end
    end
  end
  return imports
end

--- Resolve Python module to file path
---@param module_name string Python module name (e.g., "package.module")
---@param project_root string Project root directory
---@return string|nil Resolved file path
function M.resolve_module(module_name, project_root)
  local fs_exists = function(p) return p and vim.loop.fs_stat(p) ~= nil end
  local join = function(a, b) return (a:gsub("/+$", "")) .. "/" .. (b:gsub("^/+", "")) end
  
  -- Convert module name to file path
  local path_parts = vim.split(module_name, ".", { plain = true })
  local module_path = table.concat(path_parts, "/")
  
  -- Try different locations and file patterns
  local search_paths = {
    project_root,
    join(project_root, "src"),
    join(project_root, "lib"),
    join(project_root, module_name), -- For single-module packages
  }
  
  for _, base_path in ipairs(search_paths) do
    -- Try as a file
    for _, ext in ipairs(M.extensions) do
      local file_path = join(base_path, module_path .. ext)
      if fs_exists(file_path) then
        return file_path
      end
    end
    
    -- Try as a package (__init__.py)
    local package_path = join(base_path, module_path, "__init__.py")
    if fs_exists(package_path) then
      return package_path
    end
  end
  
  return nil
end

--- Get Python-specific context
---@param base_context table Base context from builder
---@param opts table Options
---@return table Enhanced context with Python specific data
function M.enhance_context(base_context, opts)
  opts = opts or {}
  local root = base_context.project_root
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  
  -- Parse imports
  local imports = M.parse_imports(lines)
  local import_samples = {}
  local seen = {}
  
  for _, module_name in ipairs(imports) do
    if not seen[module_name] then
      seen[module_name] = true
      local resolved = M.resolve_module(module_name, root)
      if resolved then
        local f = io.open(resolved, "r")
        if f then
          local content = f:read("*a") or ""
          f:close()
          if content ~= "" then
            local sample = content:sub(1, opts.max_import_chars or 1500)
            table.insert(import_samples, {
              module = module_name,
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
  
  -- Add Python-specific context
  base_context.imports = import_samples
  base_context.python_config = {
    virtual_env = vim.env.VIRTUAL_ENV,
    python_path = vim.env.PYTHONPATH,
  }
  
  return base_context
end

return M