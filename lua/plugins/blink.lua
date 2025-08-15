-- lua/plugins/blink.lua
return {
  {
    "saghen/blink.cmp",
    event = "InsertEnter",
    dependencies = {
      "L3MON4D3/LuaSnip",
      "saghen/blink.compat",
      "kikito/inspect.lua",
    },

    config = function()
      local opts = {
        sources = {
          default = {
            "ai_snippets",
            "lsp",
            -- "copilot",
            "path",
            "snippets",
            "buffer",
          },
          providers = {
            -- copilot = { module = "blink-cmp-copilot", score_offset = 120, kind = "Copilot" },
            ai_snippets = {
              name = "AI Snippets",
              module = "ai_snippets.source",
            },
          },
        },

        -- cmdline = { enabled = false },

        keymap = {
          preset = "enter",
          -- ["<C-y>"] = { "select_and_accept" },
        },
      }

      require("blink.cmp").setup(opts)
    end,
  },
}
