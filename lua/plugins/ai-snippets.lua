return {
  -- Local cmp source consumed via blink.compat
  {
    dir = vim.fn.stdpath("config") .. "/lua/ai_snippets",
    name = "cmp-ai-snippets-local",
    event = "VeryLazy",
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "saghen/blink.compat", version = "1.*" },
    },
    config = function()
      require("ai_snippets.source").register()
    end,
  },

  -- Tell Blink about the compat provider "ai_snippets"
  {
    "saghen/blink.cmp",
    opts = function(_, opts)
      opts.sources = opts.sources or {}
      opts.sources.compat = opts.sources.compat or {}
      if not vim.tbl_contains(opts.sources.compat, "ai_snippets") then
        table.insert(opts.sources.compat, "ai_snippets")
      end

      local d = opts.sources.default or {}
      local function ensure_in(t, val, after)
        if vim.tbl_contains(t, val) then
          return t
        end
        if after then
          for i, v in ipairs(t) do
            if v == after then
              table.insert(t, i + 1, val)
              return t
            end
          end
        end
        table.insert(t, 1, val)
        return t
      end
      opts.sources.default = ensure_in(d, "ai_snippets", "lsp")
    end,
  },
}
