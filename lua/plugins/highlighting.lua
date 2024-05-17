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
        "scss",
      })
      -- enable autotagging for Vue files
      opts.autotag = {
        enable = true,
        filetypes = { "html", "xml", "vue" },
      }
      -- enable syntax highlighting for Vue files
      opts.highlight = {
        enable = true,
        additional_vim_regex_highlighting = false,
      }
    end,
  },
}
