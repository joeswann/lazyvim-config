return {
  {
    "zbirenbaum/copilot-cmp",
    config = function()
      require("copilot_cmp").setup({
        panel = { enabled = true, layout = { position = "right" } },
        suggestion = { enabled = false },
      })
    end,
  },
  {
    "sourcegraph/sg.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("sg").setup({
        enable_cody = true,
        accept_tos = true,
        download_binaries = true,
      })
    end,
    build = "nvim -l build/init.lua",
  },
}
