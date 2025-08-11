return {
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "kyazdani42/nvim-web-devicons" },
    enabled = true,
    config = function()
      local api = require("nvim-tree.api")

      local function on_attach_change(bufnr)
        local function opts(desc)
          return {
            desc = "nvim-tree: " .. desc,
            buffer = bufnr,
            noremap = true,
            silent = true,
            nowait = true,
          }
        end

        api.config.mappings.default_on_attach(bufnr)

        vim.keymap.set("n", "<C-e>", function()
          local current_file = vim.fn.expand("%:p")
          if current_file == "" then
            api.tree.toggle()
          else
            api.tree.collapse_all()
            api.tree.toggle({
              path = vim.fn.expand("%:p:h"),
              find_file = true,
              focus = true,
            })
          end
        end, opts("Toggle nvimtree at current file"))
      end

      require("nvim-tree").setup({
        filters = { dotfiles = false },
        on_attach = on_attach_change,
        update_focused_file = {
          enable = true,
          update_root = false,
        },
      })
    end,
  },
  { "nvim-neo-tree/neo-tree.nvim", enabled = false },
  -- {
  --   "nvim-neo-tree/neo-tree.nvim",
  --
  --   --   dependencies = {
  --   --     "nvim-lua/ple enary.nvim",
  --   --     "nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
  --   --     "MunifTanjim/nui.nvim",
  --   --     "3rd/image.nvim",
  --   --   },
  --   opts = {
  --     filesystem = {
  --       filtered_items = {
  --         hide_dotfiles = false,
  --       },
  --     },
  --   },
  -- },
}
