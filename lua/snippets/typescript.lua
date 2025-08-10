-- lua/snippets/typescriptreact.lua
local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local fmt = require("luasnip.extras.fmt").fmt
local rep = require("luasnip.extras").rep

-- helpers
local function filename_no_ext()
  return vim.fn.fnamemodify(vim.fn.expand("%:t"), ":r")
end

local function pascal(s)
  -- turn "sanity-content" | "sanity_content" | "sanityContent" into "SanityContent"
  local x = s:gsub("[^%w]+", " ")
    :gsub("(%l)(%w*)", function(a, b)
      return a:upper() .. b:lower()
    end)
    :gsub("%s+", "")
  return x
end

-- === 1) “import c” → import cn from "classnames"
-- Shows in completion when you type `import c`
-- Works even though there's a space because regTrig + wordTrig=false
ls.add_snippets("typescriptreact", {
  s({
    trig = [[^import%s+c$]],
    regTrig = true,
    wordTrig = false,
    snippetType = "autosnippet",
  }, t([[import cn from "classnames";]])),
})

-- === 2) “export const S” → export const <FileName>: DCI = ({ className }) => { … }
-- Uses current file name to derive the component name.
-- You can lock this to a specific file (SanityContent.tsx) with a condition below.
ls.add_snippets("typescriptreact", {
  s(
    {
      trig = [[^export%s+const%s+S$]],
      regTrig = true,
      wordTrig = false,
      desc = "Export component using file name + DCI",
      condition = function()
        -- return true to allow everywhere in TSX, or lock to a specific file:
        -- return vim.fn.expand("%:t") == "SanityContent.tsx"
        return true
      end,
    },
    fmt(
      [[
export const {}: DCI = ({{ className }}) => {{
  return (
    <div className={cn(className)}>
      {}
    </div>
  );
}};
]],
      {
        f(function()
          return pascal(filename_no_ext())
        end),
        i(0),
      }
    )
  ),
})

-- === 3) Quick “export const <Name>” variant without regex
-- Type `ec` then <Tab> to choose a name manually
ls.add_snippets("typescriptreact", {
  s(
    "ec",
    fmt(
      [[
export const {}: DCI = ({{ className }}) => {{
  return (
    <div className={cn(className)}>
      {}
    </div>
  );
}};
]],
      {
        i(1, pascal(filename_no_ext())),
        i(0),
      }
    )
  ),
})

-- === 4) Optional: common React imports bundle
ls.add_snippets("typescriptreact", {
  s(
    "imr",
    fmt(
      [[
import React from "react";
import cn from "classnames";
import {{ DCI }} from "~/types/DCI";
{}
]],
      { i(0) }
    )
  ),
})
