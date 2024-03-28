return {
  { "nvim-telescope/telescope.nvim", dependencies = "tsakirist/telescope-lazy.nvim" },
  -- {
  --   "nvim-telescope/telescope.nvim",
  --   dependencies = {
  --     "nvim-lua/plenary.nvim",
  --     {
  --       "nvim-telescope/telescope-fzf-native.nvim",
  --       build = "make",
  --     },
  --   },
  --   opts = {
  --     defaults = {
  --       -- your default configuration here
  --     },
  --     extensions = {
  --       fzf = {
  --         fuzzy = true,
  --         override_generic_sorter = true,
  --         override_file_sorter = true,
  --         case_mode = "smart_case",
  --       },
  --     },
  --   },
  --   config = function(_, opts)
  --     require("telescope").setup(opts)
  --     require("telescope").load_extension("fzf")
  --   end,
  -- },
}
