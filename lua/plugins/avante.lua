return {
  {
    "yetone/avante.nvim",
    build = "make",
    event = "VeryLazy",
    version = false, -- don't pin to "*"
    ---@type avante.Config
    opts = {
      provider = "openai",
      providers = {
        openai = {
          model = "gpt-5",
          timeout = 30000,
          temperature = 1, -- Use default supported value
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
