return {
  {
    "saghen/blink.cmp",
    version = "1.*", -- prebuilt binaries; or build from source
    dependencies = {
      "L3MON4D3/LuaSnip",
      "rafamadriz/friendly-snippets",
    },
    ---@type blink.cmp.Config
    opts = {
      keymap = { preset = "enter" },
      appearance = { nerd_font_variant = "mono" },
      snippets = { preset = "luasnip" },
      signature = { enabled = true },

      completion = {
        documentation = { auto_show = true },
        list = {
          selection = {
            preselect = true,
            auto_insert = false,
          },
        },
      },

      -- built-ins: lsp, path, snippets, buffer
      sources = {
        default = { "copilot", "lsp", "path", "snippets", "buffer" },
        providers = {
          -- Add external providers here (e.g. Copilot) – see optional file below.
          copilot = { module = "blink-cmp-copilot", score_offset = 120 },
        },
      },

      -- fast fuzzy; falls back to Lua if Rust matcher isn’t available
      fuzzy = { implementation = "prefer_rust_with_warning" },
    },
  },
}
