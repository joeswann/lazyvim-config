return {
  { "prisma/vim-prisma" },
  {
    "nvim-treesitter/nvim-treesitter",
    dependencies = { "windwp/nvim-ts-autotag" },
    opts = function(_, opts)
      -- ensure_installed: extend safely
      opts.ensure_installed = opts.ensure_installed or {}
      local extra = { "tsx", "vue", "typescript", "scss", "rust", "graphql" }
      for _, lang in ipairs(extra) do
        if not vim.tbl_contains(opts.ensure_installed, lang) then
          table.insert(opts.ensure_installed, lang)
        end
      end

      -- autotag config
      opts.autotag = vim.tbl_deep_extend("force", opts.autotag or {}, {
        enable = true,
        filetypes = { "html", "xml", "vue" },
      })

      -- highlight config
      opts.highlight = vim.tbl_deep_extend("force", opts.highlight or {}, {
        enable = true,
        additional_vim_regex_highlighting = false,
      })

      -- Treat .mjml files as html
      vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
        pattern = "*.mjml",
        callback = function()
          vim.bo.filetype = "html"
        end,
      })
    end,
  },
}
