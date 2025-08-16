local U = {}

local uv = vim.loop

-- Filetype to module mapping
local FILETYPE_MODULES = {
  typescript = "typescript",
  typescriptreact = "typescript",
  javascript = "typescript",
  javascriptreact = "typescript",
  python = "python",
}

--- Get the appropriate context module for a filetype
---@param filetype string The filetype
---@return table Context module
function U.get_context_module(filetype)
  local module_name = FILETYPE_MODULES[filetype] or "generic"
  local ok, module = pcall(require, "ai_context." .. module_name)
  if not ok then
    -- Fallback to generic module
    module = require("ai_context.generic")
  end
  return module
end

-- ---------- small helpers ----------
local function clamp_tail(s, n)
  if #s <= n then
    return s
  end
  return s:sub(#s - n + 1)
end

local function clamp_head(s, n)
  if #s <= n then
    return s
  end
  return s:sub(1, n)
end

local function fs_exists(p)
  return p and uv.fs_stat(p) ~= nil
end

local function join(a, b)
  return (a:gsub("/+$", "")) .. "/" .. (b:gsub("^/+", ""))
end

local function simplify(p)
  return vim.fn.simplify(p)
end

local function has_suffix(name, suffixes)
  for _, s in ipairs(suffixes) do
    if #name >= #s and name:sub(-#s) == s then
      return true
    end
  end
  return false
end

local function read_head(path, max_chars)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local data = f:read("*a") or ""
  f:close()
  if data == "" then
    return nil
  end
  return data:sub(1, max_chars)
end

local function scandir(dir, limit)
  local entries, it = {}, uv.fs_scandir(dir)
  if not it then
    return entries
  end
  while true do
    local name, t = uv.fs_scandir_next(it)
    if not name then
      break
    end
    if name ~= "." and name ~= ".." then
      table.insert(entries, { name = name, type = t })
      if limit and #entries >= limit then
        break
      end
    end
  end
  return entries
end

-- ---------- roots & docs ----------
local function project_root()
  -- 1) LSP root
  for _, c in ipairs(vim.lsp.get_active_clients({ bufnr = 0 })) do
    local r = c.config and c.config.root_dir
    if r and fs_exists(r) then
      return r
    end
  end
  -- 2) git
  local out = vim.fn.systemlist({ "git", "rev-parse", "--show-toplevel" })
  if vim.v.shell_error == 0 and out[1] and fs_exists(out[1]) then
    return out[1]
  end
  -- 3) cwd
  return uv.cwd()
end

local function collect_docs(root, max_files, max_chars)
  local picks = { "README.md", "AGENT.md", "CONTRIBUTING.md" }
  local docs = {}
  for _, f in ipairs(picks) do
    local p = join(root, f)
    if fs_exists(p) then
      local sample = read_head(p, max_chars)
      if sample then
        table.insert(docs, { path = vim.fn.fnamemodify(p, ":~:."), sample = sample })
      end
    end
  end
  -- Also peek into docs/ if present
  local docs_dir = join(root, "docs")
  if fs_exists(docs_dir) then
    for _, e in ipairs(scandir(docs_dir, max_files or 4)) do
      if e.type == "file" and e.name:match("%.md$") then
        local p = join(docs_dir, e.name)
        local sample = read_head(p, max_chars)
        if sample then
          table.insert(docs, { path = vim.fn.fnamemodify(p, ":~:."), sample = sample })
        end
      end
    end
  end
  return docs
end

-- ---------- sibling files ----------
local function collect_siblings(bufpath, max_files, max_chars)
  local dir = vim.fn.fnamemodify(bufpath, ":h")
  local cur = vim.fn.fnamemodify(bufpath, ":t")
  local out, n = {}, 0

  -- Get common code file extensions
  local code_extensions = {
    ".tsx",
    ".ts",
    ".jsx",
    ".js",
    ".py",
    ".lua",
    ".go",
    ".rs",
    ".rb",
    ".php",
    ".java",
    ".kt",
    ".swift",
    ".dart",
    ".ex",
    ".exs",
    ".elm",
    ".hs",
    ".ml",
    ".c",
    ".cpp",
    ".cc",
    ".cxx",
    ".h",
    ".hpp",
    ".cs",
    ".fs",
    ".clj",
    ".cljs",
  }

  for _, e in ipairs(scandir(dir, 80)) do
    if e.type == "file" and e.name ~= cur then
      if has_suffix(e.name, code_extensions) then
        local p = join(dir, e.name)
        local sample = read_head(p, max_chars)
        if sample then
          table.insert(out, { path = vim.fn.fnamemodify(p, ":~:."), sample = sample })
          n = n + 1
          if max_files and n >= max_files then
            break
          end
        end
      end
    end
  end
  return out
end

-- ---------- dependency files ----------
local function collect_dependency_files(root, filetype)
  -- Load filetype-specific or generic dependency patterns
  local context_module = U.get_context_module(filetype)
  local dep_files = context_module.dependency_files or {}

  -- Always include some common files
  local common_files = { "lazy-lock.json" } -- Neovim specific
  vim.list_extend(dep_files, common_files)

  local found = {}
  for _, filename in ipairs(dep_files) do
    local path = join(root, filename)
    if fs_exists(path) then
      local content = read_head(path, 8000) -- Larger limit for dependency files
      if content then
        table.insert(found, {
          filename = filename,
          path = vim.fn.fnamemodify(path, ":~:."),
          content = content,
        })
      end
    end
  end

  return found
end

-- ---------- lsp diagnostics ----------
local function collect_diagnostics(bufnr, max_items, max_text)
  local diags = vim.diagnostic.get(bufnr)
  table.sort(diags, function(a, b)
    return a.severity < b.severity
  end)
  local out = {}
  for _, d in ipairs(diags) do
    local sev = ({ "ERROR", "WARN", "INFO", "HINT" })[d.severity] or tostring(d.severity)
    local msg = (d.message or ""):gsub("\n+", " ")
    msg = clamp_head(msg, max_text or 200)
    table.insert(out, {
      lnum = (d.lnum or 0) + 1,
      col = (d.col or 0) + 1,
      severity = sev,
      source = d.source or "",
      code = d.code or "",
      message = msg,
    })
    if max_items and #out >= max_items then
      break
    end
  end
  return out
end

-- ---------- open buffers (existing behavior) ----------
local function get_open_buffers(max_bufs, max_chars_per)
  local bufs = {}
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if #bufs >= (max_bufs or 2) then
      break
    end
    if vim.api.nvim_buf_is_loaded(b) and b ~= vim.api.nvim_get_current_buf() then
      local name = vim.api.nvim_buf_get_name(b)
      if name ~= "" then
        local text = table.concat(vim.api.nvim_buf_get_lines(b, 0, -1, false), "\n")
        table.insert(bufs, {
          path = vim.fn.fnamemodify(name, ":~:."),
          sample = clamp_head(text, max_chars_per or 1500),
        })
      end
    end
  end
  return bufs
end

local function get_recent_diff_lines(filepath, max_lines)
  local ok, out = pcall(vim.fn.systemlist, { "git", "diff", "-U0", "--no-color", "--", filepath })
  if not ok or vim.v.shell_error ~= 0 then
    return nil
  end
  local lines = {}
  for _, l in ipairs(out) do
    if not l:match("^diff ") and not l:match("^index ") and not l:match("^@@") then
      table.insert(lines, l)
      if max_lines and #lines >= max_lines then
        break
      end
    end
  end
  return (#lines > 0) and table.concat(lines, "\n") or nil
end

-- Add near the other helper functions

local function collect_github_similar_files(filename, opts)
  local ok, github = pcall(require, "ai_context.github")
  if not ok then
    return {}
  end

  -- Only search for meaningful filenames (not index.tsx, etc.)
  local skip_patterns = {
    "^index%.",
    "^main%.",
    "^app%.",
    "^init%.",
    "^config%.",
    "^setup%.",
    "^test%.",
    "^spec%.",
  }

  for _, pattern in ipairs(skip_patterns) do
    if filename:match(pattern) then
      return {}
    end
  end

  -- Get the current git repo name to exclude it
  local current_repo = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):match("([^/]+)$")
  current_repo = current_repo and current_repo:gsub("%s+", "") or nil

  -- Safely call search_similar_files with error handling
  local ok_search, results = pcall(github.search_similar_files, filename, {
    max_results = opts.max_github_files or 2,
    exclude_repos = current_repo and { current_repo } or {},
  })

  if not ok_search then
    return {}
  end

  -- Format results for context
  local formatted = {}
  for _, result in ipairs(results or {}) do
    if result and result.content then
      table.insert(formatted, {
        repo = result.repo,
        path = result.path,
        url = result.html_url,
        content = result.content:sub(1, opts.max_github_content or 3000),
      })
    end
  end

  return formatted
end
-- ---------- public: build_context ----------
function U.build_context(opts)
  opts = opts or {}
  local ft = vim.bo.filetype
  local file = vim.fn.expand("%:p")
  local filename = vim.fn.expand("%:t")
  local bufnr = vim.api.nvim_get_current_buf()
  local cwd = uv.cwd()
  local root = project_root()

  print("[AI Context] Building context for file:", filename, "filetype:", ft)
  print("[AI Context] Project root:", root)

  local row, col = 1, 0
  -- Safe cursor position handling for headless mode
  if vim.api.nvim_get_mode().mode ~= "c" then
    local ok, cursor = pcall(vim.api.nvim_win_get_cursor, 0)
    if ok and cursor then
      row, col = unpack(cursor)
    end
  end

  -- Get all lines from buffer
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  -- Split into before (lines before current), current (text on current line), and after (lines after current)
  local before_lines = {}
  local current_line = ""
  local after_lines = {}

  if #lines > 0 then
    -- Lines before current line
    for i = 1, math.max(0, row - 1) do
      if lines[i] then
        table.insert(before_lines, lines[i])
      end
    end

    -- Current line up to cursor position
    if lines[row] then
      current_line = lines[row]:sub(1, col)
    end

    -- Lines after current line
    for i = row + 1, #lines do
      if lines[i] then
        table.insert(after_lines, lines[i])
      end
    end
  end

  local before = table.concat(before_lines, "\n")
  local current = current_line
  local after = table.concat(after_lines, "\n")

  -- Build base context
  local github_similar = collect_github_similar_files(filename, opts)
  print("[AI Context] GitHub similar files found:", #github_similar)
  if #github_similar > 0 then
    print("[AI Context] GitHub similar files:")
    for i, file in ipairs(github_similar) do
      print("  ", i, file.repo .. "/" .. file.path, "(" .. #file.content .. " chars)")
    end
  end

  local ctx = {
    cwd = cwd,
    language = ft,
    filename = filename,
    filepath = vim.fn.fnamemodify(file, ":~:."),
    project_root = vim.fn.fnamemodify(root, ":~:."),
    cursor = { row = row, col = col },

    current = current,
    before = clamp_tail(before, opts.max_before or 2400),
    after = clamp_head(after, opts.max_after or 1200),

    dependencies = collect_dependency_files(root, ft),

    github_similar = github_similar,

    -- open_buffers = get_open_buffers(opts.max_open_buffers or 3, opts.max_open_buf_chars or 1200),
    -- recent_edits = get_recent_diff_lines(file, opts.max_recent_diff_lines or 120) or "",

    -- docs = collect_docs(root, opts.max_docs or 4, opts.max_doc_chars or 2000),
    -- lsp = { diagnostics = collect_diagnostics(bufnr, opts.max_diag or 30, opts.max_diag_text or 240) },

    -- Always collect siblings for any filetype
    -- siblings = collect_siblings(file, opts.max_siblings or 4, opts.max_sibling_chars or 1200),
  }

  -- Get filetype-specific context enhancement
  local context_module = U.get_context_module(ft)
  if context_module.enhance_context then
    ctx = context_module.enhance_context(ctx, opts)
  end

  print("[AI Context] Final context structure:")
  print(vim.inspect({
    language = ctx.language,
    filename = ctx.filename,
    cursor_pos = ctx.cursor,
    current_text_length = #ctx.current,
    before_text_length = #ctx.before,
    after_text_length = #ctx.after,
    dependencies_count = #ctx.dependencies,
    github_similar_count = #ctx.github_similar,
  }))

  return ctx
end

return U
