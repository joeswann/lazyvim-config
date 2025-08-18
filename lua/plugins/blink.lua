-- lua/plugins/blink.lua
return {
  {
    "saghen/blink.cmp",
    event = "InsertEnter",
    dependencies = {
      "saghen/blink.compat",
      "L3MON4D3/LuaSnip",
      "kikito/inspect.lua",
    },

    opts = {
      snippets = { preset = "luasnip" },
      sources = {
        default = {
          -- "copilot",
          -- "ai_suggestions",
          "lsp",
          "path",
          "snippets",
          "buffer",
        },
        providers = {
          snippets = { score_offset = 100 }, -- make snippets rank higher
          ai_suggestions = {
            name = "AI",
            module = "ai_suggestions.source",
            snippets = { score_offset = 120 }, -- make snippets rank higher
          },
        },
      },
      keymap = {
        preset = "enter",
      },
    },
  },
}
