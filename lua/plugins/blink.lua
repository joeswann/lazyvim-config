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

    config = function(_, opts)
      opts.sources.default = {
        -- "copilot",
        "ai_suggestions",
        "lsp",
        "path",
        "snippets",
        "buffer",
      }

      opts.sources.providers = opts.sources.providers or {}
      opts.sources.providers.ai_suggestions = {
        name = "AI Snippets",
        module = "ai_suggestions.source",
      }

      opts.keymap.preset = "enter"
      require("blink.cmp").setup(opts)
    end,
  },
}
