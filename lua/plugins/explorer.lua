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
        default_file_explorer = true,
        keymaps = {
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
  -- { "nvim-neo-tree/neo-tree.nvim", enabled = false },
  {
    "nvim-neo-tree/neo-tree.nvim",

    --   dependencies = {
    --     "nvim-lua/ple enary.nvim",
    --     "nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
    --     "MunifTanjim/nui.nvim",
    --     "3rd/image.nvim",
    --   },
    opts = {
      filesystem = {
        filtered_items = {
          hide_dotfiles = false,
        },
      },
    },
  },
}
