-- lua/plugins/blink.lua
return {
  {
    "saghen/blink.cmp",
    version = "1.*",
    event = "InsertEnter",
    dependencies = {
      "L3MON4D3/LuaSnip",
      "rafamadriz/friendly-snippets",
      -- Allow nvim-cmp sources through blink.compat when any extras need them
      { "saghen/blink.compat", optional = true, opts = {}, version = "1.*" },
    },

    -- Let Lazy merge these arrays with anything else that extends Blink
    opts_extend = {
      "sources.completion.enabled_providers",
      "sources.compat",
      "sources.default",
    },

    ---@type blink.cmp.Config | { sources: { compat: string[] } }
    opts = {
      snippets = {
        -- Use LazyVim’s helper (works great with LuaSnip)
        expand = function(snippet, _)
          return LazyVim.cmp.expand(snippet)
        end,
      },

      appearance = {
        use_nvim_cmp_as_default = false,
        nerd_font_variant = "mono",
      },

      completion = {
        accept = {
          auto_brackets = { enabled = true },
        },
        menu = {
          draw = { treesitter = { "lsp" } },
        },
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 200,
        },
        ghost_text = {
          enabled = true,
        },
      },

      -- experimental signature help support
      -- signature = { enabled = true },

      sources = {
        -- any nvim-cmp sources added elsewhere can be enabled through compat
        compat = {},
        -- built-ins
        default = {
          "lsp",
          "copilot",
          "path",
          "snippets",
          "buffer",
        },
        providers = {
          -- Copilot provider (optional; requires giuxtaposition/blink-cmp-copilot)
          copilot = { module = "blink-cmp-copilot", score_offset = 120, kind = "Copilot" },
        },
      },

      cmdline = { enabled = false },

      keymap = {
        preset = "enter",
        -- ["<CR>"] = { "select_and_accept" },
        ["<C-y>"] = { "select_and_accept" },
        -- <Tab> will be added in config() to also perform ai_accept
      },
    },

    config = function(_, opts)
      -- enable compat sources (nvim-cmp sources) if any were listed
      local enabled = opts.sources.default
      for _, source in ipairs(opts.sources.compat or {}) do
        opts.sources.providers = opts.sources.providers or {}
        opts.sources.providers[source] = vim.tbl_deep_extend(
          "force",
          { name = source, module = "blink.compat.source" },
          opts.sources.providers[source] or {}
        )
        if type(enabled) == "table" and not vim.tbl_contains(enabled, source) then
          table.insert(enabled, source)
        end
      end

      -- Promote custom provider kinds to Blink kinds for proper icons
      for _, provider in pairs(opts.sources.providers or {}) do
        if provider.kind then
          local CompletionItemKind = require("blink.cmp.types").CompletionItemKind
          local kind_idx = #CompletionItemKind + 1
          CompletionItemKind[kind_idx] = provider.kind
          CompletionItemKind[provider.kind] = kind_idx

          local transform_items = provider.transform_items
          provider.transform_items = function(ctx, items)
            items = transform_items and transform_items(ctx, items) or items
            for _, item in ipairs(items) do
              item.kind = kind_idx or item.kind
              item.kind_icon = LazyVim.config.icons.kinds[item.kind_name] or item.kind_icon or nil
            end
            return items
          end

          -- remove custom field after we’ve used it (Blink validates config)
          provider.kind = nil
        end
      end

      -- remove compat key so Blink’s validator is happy
      opts.sources.compat = nil

      require("blink.cmp").setup(opts)
    end,
  },
}
