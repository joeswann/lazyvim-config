return {
  {
    dir = vim.fn.stdpath("config") .. "/lua/ai_snippets",
    name = "ai-snippets-local",
    event = "InsertEnter",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
  },

  {
    "saghen/blink.cmp",
    opts = function(_, opts)
      opts.sources = opts.sources or {}
      opts.sources.default = opts.sources.default or {}
      
      -- Add ai_snippets to the default sources
      if not vim.tbl_contains(opts.sources.default, "ai_snippets") then
        -- Insert after LSP but before copilot
        local lsp_idx = nil
        for i, v in ipairs(opts.sources.default) do
          if v == "lsp" then lsp_idx = i break end
        end
        if lsp_idx then
          table.insert(opts.sources.default, lsp_idx + 1, "ai_snippets")
        else
          table.insert(opts.sources.default, 1, "ai_snippets")
        end
      end

      -- Configure the native blink.cmp source
      opts.sources.providers = opts.sources.providers or {}
      opts.sources.providers.ai_snippets = {
        name = "AI Snippets",
        module = "ai_snippets.blink_source",
        score_offset = 200, -- Higher than copilot (120)
      }
    end,
  },
}
