return {
  {
    "L3MON4D3/LuaSnip",
    keys = function()
      return {}
    end,
  },
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-emoji",
      "lukas-reineke/cmp-under-comparator",
      "milanglacier/minuet-ai.nvim",
      -- { "yetone/avante.nvim" },
    },
    opts = function(_, opts)
      local luasnip = require("luasnip")
      local cmp = require("cmp")

      -- -- Make sure we properly initialize the sources table
      opts.sources = cmp.config.sources({
        { name = "minuet" },
        { name = "nvim_lsp" },
        { name = "luasnip" },
        { name = "buffer" },
        { name = "path" },
        -- { name = "avante" }, -- Add avante source
      })

      -- if you wish to use autocomplete
      -- table.insert(opts.sources, 1, {
      --   name = "minuet",
      --   group_index = 1,
      --   priority = 100,
      -- })

      -- Set up sorting and comparators
      opts.sorting = {
        priority_weight = 2,
        comparators = {
          cmp.config.compare.offset,
          cmp.config.compare.exact,
          cmp.config.compare.score,
          require("cmp-under-comparator").under,
          function(entry1, entry2)
            local count1 = entry1.completion_item.data and entry1.completion_item.data.usage_count or 0
            local count2 = entry2.completion_item.data and entry2.completion_item.data.usage_count or 0
            return count1 > count2
          end,
          cmp.config.compare.kind,
          cmp.config.compare.sort_text,
          cmp.config.compare.length,
          cmp.config.compare.order,
        },
      }

      opts.performance = {
        fetching_timeout = 2000, -- Increase timeout to 2 seconds
      }

      -- Make sure we have mapping properly configured
      local has_words_before = function()
        unpack = unpack or table.unpack
        local line, col = unpack(vim.api.nvim_win_get_cursor(0))
        return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
      end

      opts.mapping = vim.tbl_extend("force", opts.mapping or {}, {
        ["<Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_next_item()
          elseif luasnip.expand_or_jumpable() then
            luasnip.expand_or_jump()
          elseif has_words_before() then
            cmp.complete()
          else
            fallback()
          end
        end, { "i", "s" }),
        ["<S-Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_prev_item()
          elseif luasnip.jumpable(-1) then
            luasnip.jump(-1)
          else
            fallback()
          end
        end, { "i", "s" }),
      })

      return opts
    end,
  },
}
