-- Generic context patterns for languages without specific modules
local M = {}

-- Generic dependency files that might be useful across languages
M.dependency_files = {
  "Makefile",
  "CMakeLists.txt",
  "Dockerfile",
  "docker-compose.yml",
  ".gitignore",
  "README.md",
  "LICENSE",
  "CONTRIBUTING.md",
}

-- Language-specific dependency patterns
local language_deps = {
  rust = { "Cargo.toml", "Cargo.lock" },
  go = { "go.mod", "go.sum" },
  php = { "composer.json", "composer.lock" },
  ruby = { "Gemfile", "Gemfile.lock", ".ruby-version" },
  java = { "pom.xml", "build.gradle", "build.gradle.kts", "gradle.properties" },
  kotlin = { "build.gradle.kts", "build.gradle", "pom.xml" },
  swift = { "Package.swift", "Package.resolved" },
  dart = { "pubspec.yaml", "pubspec.lock" },
  elixir = { "mix.exs", "mix.lock" },
  erlang = { "rebar.config", "erlang.mk" },
  clojure = { "project.clj", "deps.edn", "shadow-cljs.edn" },
  haskell = { "cabal.project", "stack.yaml", "package.yaml" },
  ocaml = { "dune-project", "opam" },
  elm = { "elm.json" },
  nim = { "*.nimble" },
  zig = { "build.zig" },
  c = { "Makefile", "CMakeLists.txt", "configure.ac" },
  cpp = { "Makefile", "CMakeLists.txt", "conanfile.txt", "vcpkg.json" },
  csharp = { "*.csproj", "*.sln", "packages.config", "Directory.Build.props" },
  fsharp = { "*.fsproj", "paket.dependencies" },
}

--- Get dependency files for a specific language
---@param filetype string The filetype to get dependencies for
---@return table Array of dependency file patterns
function M.get_dependency_files(filetype)
  local deps = vim.deepcopy(M.dependency_files)
  
  -- Add language-specific dependencies
  local lang_deps = language_deps[filetype]
  if lang_deps then
    vim.list_extend(deps, lang_deps)
  end
  
  return deps
end

--- Get generic context (fallback for unsupported languages)
---@param base_context table Base context from builder
---@param opts table Options
---@return table Enhanced context
function M.enhance_context(base_context, opts)
  opts = opts or {}
  
  -- For generic languages, we just return the base context
  -- Individual language modules will override this
  return base_context
end

--- Parse imports using simple heuristics
---@param lines table Array of file lines
---@param patterns table Array of regex patterns to match
---@return table Array of import/require statements
function M.parse_imports_generic(lines, patterns)
  local imports = {}
  for _, line in ipairs(lines) do
    for _, pattern in ipairs(patterns or {}) do
      local match = line:match(pattern)
      if match then
        table.insert(imports, match)
        break
      end
    end
  end
  return imports
end

return M