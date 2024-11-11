return {

  {
    "nvim-lspconfig",
    opts = function(_, opts)
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

      opts.setup = {
        -- This will be called for each LSP server that's set up
        ["*"] = function(server, server_opts)
          server_opts.handlers = server_opts.handlers or {}
          server_opts.handlers["textDocument/hover"] = require("noice").hover
          server_opts.handlers["textDocument/signatureHelp"] = require("noice").signature
        end,
      }

      return opts
    end,
    dependencies = {
      "folke/noice.nvim",
    },
  },
}
