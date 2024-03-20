return {
  -- add Toggle Term
  {
    "akinsho/toggleterm.nvim",
    config = true,
    cmd = "ToggleTerm",
    keys = { { "<C-\\>", "<cmd>ToggleTerm<cr>", desc = "Toggle floating terminal" } },
    opts = {
      open_mapping = [[<C-\>]],
      direction = "float",
      shade_filetypes = {},
      hide_numbers = true,
      insert_mappings = true,
      terminal_mappings = true,
      start_in_insert = true,
      close_on_exit = true,
    },
  },

  -- Persistence
  --
  -- { 'echasnovski/mini.align', version = '*' },

  -- Align plugin
  -- { "junegunn/vim-easy-align" },
  { "echasnovski/mini.align", version = "*" },

  --disable mini.pairs
  { "echasnovski/mini.pairs", enabled = false },

  -- ts utils
  -- {
  --   "jose-elias-alvarez/nvim-lsp-ts-utils",
  -- },

  -- add obsidian

  -- {
  --"epwalsh/obsidian",
  -- version = "*",
  -- dependencies = { "nvim-lua/plenary.nvim" },
  -- opts = { workspaces = { name = "todo", path = "~/personal/todo" } },
  -- },
  --
  -- Refactoring
  {
    "ThePrimeagen/refactoring.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      require("refactoring").setup()
    end,
  },

  -- neo-tree
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = {
      filesystem = {
        filtered_items = {
          hide_dotfiles = false,
        },
        -- components = {
        --   harpoon_index = function(config, node, _)
        --     local harpoon_list = require("harpoon"):list()
        --     local path = node:get_id()
        --     local harpoon_key = vim.uv.cwd()
        --
        --     for i, item in ipairs(harpoon_list.items) do
        --       local value = item.value
        --       if string.sub(item.value, 1, 1) ~= "/" then
        --         value = harpoon_key .. "/" .. item.value
        --       end
        --
        --       if value == path then
        --         vim.print(path)
        --         return {
        --           text = string.format(" ⥤ %d", i), -- <-- Add your favorite harpoon like arrow here
        --           highlight = config.highlight or "NeoTreeDirectoryIcon",
        --         }
        --       end
        --     end
        --     return {}
        --   end,
        -- },
        -- renderers = {
        --   file = {
        --     { "icon" },
        --     { "name", use_git_status_colors = true },
        --     { "harpoon_index" }, --> This is what actually adds the component in where you want it
        --     { "diagnostics" },
        --     { "git_status", highlight = "NeoTreeDimText" },
        --   },
        -- },
      },
    },
  },

  -- add gruvbox

  { "ellisonleao/gruvbox.nvim" },

  -- configure LazyVim to load gruvbox
  {
    "lazyVim/LazyVim",
    opts = {
      colorscheme = "gruvbox",
    },
  },

  -- since `vim.tbl_deep_extend`, can only merge tables and not lists, the code above
  -- would overwrite `ensure_installed` with the new value.
  -- If you'd rather extend the default config, use the code below instead:
  {
    "nvim-treesitter/nvim-treesitter",
    dependencies = { { "windwp/nvim-ts-autotag" } },
    opts = function(_, opts)
      -- add tsx and treesitter
      vim.list_extend(opts.ensure_installed, {
        "tsx",
        "typescript",
      })
    end,
  },

  -- Use <tab> for completion and snippets (supertab)
  -- first: disable default <tab> and <s-tab> behavior in LuaSnip
  {
    "L3MON4D3/LuaSnip",
    keys = function()
      return {}
    end,
  },
  -- then: setup supertab in cmp
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-emoji",
    },
    ---@param opts cmp.ConfigSchema
    opts = function(_, opts)
      local has_words_before = function()
        unpack = unpack or table.unpack
        local line, col = unpack(vim.api.nvim_win_get_cursor(0))
        return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
      end

      local luasnip = require("luasnip")
      local cmp = require("cmp")

      opts.mapping = vim.tbl_extend("force", opts.mapping, {
        ["<Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_next_item()
            -- You could replace the expand_or_jumpable() calls with expand_or_locally_jumpable()
            -- this way you will only jump inside the snippet region
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
    end,
  },
}
