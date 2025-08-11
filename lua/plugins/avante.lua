return {
  {
    "yetone/avante.nvim",
    -- use prebuilt binaries; falls back to building via `make`
    build = (vim.fn.has("win32") == 1) and "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false"
      or "make",
    event = "VeryLazy",
    version = false, -- don't pin to "*"
    ---@type avante.Config
    opts = {
      -- Use Gemini as the primary provider
      provider = "gemini",
      providers = {
        gemini = {
          -- endpoint is optional; Avante knows Gemini,
          -- but keeping it explicit is fine if you prefer:
          -- endpoint = "https://generativelanguage.googleapis.com/v1beta",
          model = "gemini-2.0-pro", -- or "gemini-2.0-flash" for snappier replies
          timeout = 30000,
          -- extra_request_body = { temperature = 0.4 },
        },
      },

      -- Nice input UI (you already have snacks + dressing)
      input = { provider = "snacks" },
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      -- ensure Avante output renders nicely
      {
        "MeanderingProgrammer/render-markdown.nvim",
        opts = function(_, opts)
          opts = opts or {}
          opts.file_types = opts.file_types or { "markdown" }
          if not vim.tbl_contains(opts.file_types, "Avante") then
            table.insert(opts.file_types, "Avante")
          end
          return opts
        end,
        ft = { "markdown", "Avante" },
      },
      "stevearc/dressing.nvim",
      "folke/snacks.nvim",
      "nvim-tree/nvim-web-devicons",
    },
  },
}
