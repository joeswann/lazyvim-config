return {
  "saghen/blink.cmp",
  version = "1.*",
  dependencies = {
    -- Snippets
    { "L3MON4D3/LuaSnip", version = "v2.*" },
    "rafamadriz/friendly-snippets",
    -- Copilot source for blink
    "giuxtaposition/blink-cmp-copilot",
  },
  opts = {
    snippets = { preset = "luasnip" },
    sources = {
      -- blink ships `lsp`, `snippets`, `path`, `buffer` as defaults
      default = { "lsp", "path", "snippets", "buffer", "copilot" },
      providers = {
        copilot = {
          name = "copilot",
          module = "blink-cmp-copilot",
          score_offset = 100,
          async = true,
        },
      },
    },
    keymap = { preset = "super-tab" }, -- or your custom one
  },
}
