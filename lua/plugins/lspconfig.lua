-- lua/plugins/lspconfig.lua
return {
  {
    "nvim-lspconfig",
    dependencies = {
      "folke/noice.nvim",
      "saghen/blink.cmp",
    },

    ---@param opts table Existing LazyVim opts for lspconfig
    opts = function(_, opts)
      --------------------------------------------------------------------------
      -- Diagnostics UI tweaks --------------------------------------------------
      --------------------------------------------------------------------------
      opts.diagnostics = {
        virtual_text = false,
        float = {
          focus = false,
          border = "rounded",
          source = "always",
          format = function(diagnostic)
            return string.format("%s (%s)", diagnostic.message, diagnostic.source)
          end,
        },
      }

      --------------------------------------------------------------------------
      -- Global handler overrides ----------------------------------------------
      --------------------------------------------------------------------------
      opts.setup = {
        -- Run for *every* server
        ["*"] = function(_, server_opts)
          server_opts.handlers = server_opts.handlers or {}
          server_opts.handlers["textDocument/hover"] = require("noice").hover
          server_opts.handlers["textDocument/signatureHelp"] = require("noice").signature
        end,
      }

      --------------------------------------------------------------------------
      -- ESLint language-server -------------------------------------------------
      --------------------------------------------------------------------------
      opts.servers = opts.servers or {}
      opts.servers.eslint = vim.tbl_deep_extend("force", opts.servers.eslint or {}, {
        settings = {
          -- Let the server search upward until it finds an ESLint config
          workingDirectories = { mode = "auto" },

          -- Uncomment the next line if you’re already on ESLint 9 (flat-config)
          -- useFlatConfig = true,
        },
      })

      return opts
    end,
  },
}
