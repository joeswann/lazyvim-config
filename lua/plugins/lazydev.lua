return {
  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      -- enrich completion/types for common libs you use
      library = {
        "lazy.nvim",
        { path = "lazyvim", words = { "LazyVim" } },
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
      },
    },
  },

  -- ensure lua_ls is configured (merged with your existing lspconfig)
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      opts.servers.lua_ls = vim.tbl_deep_extend("force", opts.servers.lua_ls or {}, {
        settings = {
          Lua = {
            completion = { callSnippet = "Replace" },
            workspace = { checkThirdParty = false },
          },
        },
      })
      return opts
    end,
  },
}
