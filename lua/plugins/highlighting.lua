return {
  { "prisma/vim-prisma" },
  {
    "nvim-treesitter/nvim-treesitter",
    dependencies = { { "windwp/nvim-ts-autotag" } },
    opts = function(_, opts)
      -- add tsx and treesitter
      vim.list_extend(opts.ensure_installed, {
        "tsx",
        "vue",
        "typescript",
      })
    end,
  },
}
