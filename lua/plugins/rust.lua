-- lua/plugins/rust.lua
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        rust_analyzer = {
          settings = {
            ["rust-analyzer"] = {
              checkOnSave = {
                command = "clippy",
              },
            },
          },
        },
      },
    },
  },
  {
    "williamboman/mason.nvim",
    opts = function(_, opts)
      table.insert(opts.ensure_installed, "rust-analyzer")
    end,
  },
  {
    "simrat39/rust-tools.nvim",
    lazy = true,
    opts = function()
      return {
        tools = {
          inlay_hints = {
            auto = true,
          },
        },
      }
    end,
  },
}
