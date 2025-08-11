local U = {}

local uv = vim.loop

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

-- ---------- tsconfig alias parsing ----------
local function load_ts_aliases(root)
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

  -- common custom alias: "~" → src
  if not alias["~"] and fs_exists(join(root, "src")) then
    alias["~"] = join(root, "src")
  end

  return alias, baseUrlAbs
end

-- ---------- import resolution ----------
local exts = { ".tsx", ".ts", ".jsx", ".js", ".d.ts", ".json", ".css", ".module.css" }

local function try_resolve(base, frag)
  -- explicit extension?
  local candidates = {}
  if frag:match("%.%w+$") then
    table.insert(candidates, frag)
  else
    for _, e in ipairs(exts) do
      table.insert(candidates, frag .. e)
    end
    for _, e in ipairs(exts) do
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

local function resolve_import(raw, file_dir, root, alias, baseUrlAbs)
  if raw:match("^%.") then
    return try_resolve(file_dir, raw)
  end
  if raw:match("^/") then
    return try_resolve(root, raw)
  end
  -- alias prefix
  for pref, target in pairs(alias or {}) do
    if raw == pref or raw:sub(1, #pref + 1) == (pref .. "/") then
      local rest = raw:sub(#pref + 2)
      return try_resolve(target, rest)
    end
  end
  -- bare import -> baseUrl or node_modules (we skip node_modules contents)
  if baseUrlAbs then
    local p = try_resolve(baseUrlAbs, raw)
    if p then
      return p
    end
  end
  return nil
end

local function parse_imports(lines)
  local imports = {}
  for _, l in ipairs(lines) do
    -- use quoted strings so we don't collide with ]] in long brackets
    local m = l:match("import%s+.-from%s+['\"](.-)['\"]")
      or l:match("import%s*%(%s*['\"](.-)['\"]%s*%)") -- dynamic import('x')
      or l:match("require%s*%(%s*['\"](.-)['\"]%s*%)") -- require('x')

    if m and not m:match("^node:") and not m:match("^https?://") then
      table.insert(imports, m)
    end
  end
  return imports
end

local function collect_import_samples(bufdir, root, alias, baseUrlAbs, lines, max_files, max_chars)
  local found, out, seen = parse_imports(lines), {}, {}
  for _, raw in ipairs(found) do
    if not seen[raw] then
      seen[raw] = true
      local resolved = resolve_import(raw, bufdir, root, alias, baseUrlAbs)
      if resolved and fs_exists(resolved) and not resolved:match("/node_modules/") then
        local sample = read_head(resolved, max_chars)
        if sample then
          table.insert(out, { raw = raw, path = vim.fn.fnamemodify(resolved, ":~:."), sample = sample })
          if max_files and #out >= max_files then
            break
          end
        end
      end
    end
  end
  return out
end

-- ---------- sibling files ----------
local function collect_siblings(bufpath, max_files, max_chars)
  local dir = vim.fn.fnamemodify(bufpath, ":h")
  local cur = vim.fn.fnamemodify(bufpath, ":t")
  local out, n = {}, 0
  for _, e in ipairs(scandir(dir, 80)) do
    if e.type == "file" and e.name ~= cur then
      if has_suffix(e.name, { ".tsx", ".ts", ".jsx", ".js", ".css", ".module.css" }) then
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

-- ---------- public: build_context ----------
function U.build_context(opts)
  opts = opts or {}
  local ft = vim.bo.filetype
  local file = vim.fn.expand("%:p")
  local filename = vim.fn.expand("%:t")
  local bufnr = vim.api.nvim_get_current_buf()
  local cwd = uv.cwd()
  local root = project_root()

  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local all = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  local before = all:sub(1, vim.api.nvim_buf_get_offset(0, row - 1) + col)
  local after = all:sub(vim.api.nvim_buf_get_offset(0, row - 1) + col + 1)

  local ctx = {
    language = ft,
    filename = filename,
    filepath = vim.fn.fnamemodify(file, ":~:."),
    project_root = vim.fn.fnamemodify(root, ":~:."),
    cwd = cwd,
    cursor = { row = row, col = col },

    before = clamp_tail(before, opts.max_before or 2800),
    after = clamp_head(after, opts.max_after or 1400),

    open_buffers = get_open_buffers(opts.max_open_buffers or 3, opts.max_open_buf_chars or 1200),
    recent_edits = get_recent_diff_lines(file, opts.max_recent_diff_lines or 120) or "",

    docs = collect_docs(root, opts.max_docs or 4, opts.max_doc_chars or 2000),
    lsp = { diagnostics = collect_diagnostics(bufnr, opts.max_diag or 30, opts.max_diag_text or 240) },
  }

  -- TS/JS/TSX/JSX: resolve imports & sample siblings for extra context
  if ft == "typescriptreact" or ft == "typescript" or ft == "javascriptreact" or ft == "javascript" then
    local alias, baseUrlAbs = load_ts_aliases(root)
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local bufdir = vim.fn.fnamemodify(file, ":p:h")
    ctx.imports = collect_import_samples(
      bufdir,
      root,
      alias,
      baseUrlAbs,
      lines,
      opts.max_imports or 8,
      opts.max_import_chars or 1500
    )
    ctx.siblings = collect_siblings(file, opts.max_siblings or 4, opts.max_sibling_chars or 1200)
    ctx.ts_paths = { alias = alias, baseUrl = baseUrlAbs }
  end

  return ctx
end

return U
