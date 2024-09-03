return {
  {
    "stevearc/oil.nvim",
    config = function()
      local oil = require("oil")

      local function custom_open_dir()
        local node = oil.get_cursor_entry()
        if node and node.type == "directory" then
          oil.select()
        end
      end

      oil.setup({
        view_options = {
          show_hidden = true,
        },
        default_file_explorer = true,
        keymaps = {
          ["g?"] = "actions.show_help",
          ["<CR>"] = "actions.select",
          ["<C-s>"] = { "actions.select", opts = { vertical = true }, desc = "Open the entry in a vertical split" },
          ["<C-h>"] = { "actions.select", opts = { horizontal = true }, desc = "Open the entry in a horizontal split" },
          ["<C-t>"] = { "actions.select", opts = { tab = true }, desc = "Open the entry in new tab" },
          ["<C-p>"] = "actions.preview",
          ["<C-c>"] = "actions.close",
          ["<C-l>"] = "actions.refresh",
          ["-"] = "actions.parent",
          ["_"] = "actions.open_cwd",
          ["`"] = "actions.cd",
          ["~"] = { "actions.cd", opts = { scope = "tab" }, desc = ":tcd to the current oil directory" },
          ["gs"] = "actions.change_sort",
          ["gx"] = "actions.open_external",
          ["g."] = "actions.toggle_hidden",
          ["g\\"] = "actions.toggle_trash",
          ["<esc><esc>"] = "actions.close",
          ["<bs>"] = "actions.parent",
          ["h"] = "actions.parent",
          ["l"] = "actions.select",
          ["x"] = {
            callback = function()
              custom_open_dir()
            end,
            desc = "Navigate into directory",
          },
        },
      })
    end,
    dependencies = { "nvim-tree/nvim-web-devicons" },
  },
  {
    "nvim-tree/nvim-tree.lua",
    requires = { "kyazdani42/nvim-web-devicons" },
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
          api.tree.toggle({ file_path = true })
        end, opts("Toggle nvimtree"))
      end

      require("nvim-tree").setup({
        filters = { dotfiles = true },
        on_attach = on_attach_change,
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
