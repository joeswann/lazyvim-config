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
  --   "lambdalisue/fern.vim",
  --   dependencies = {
  --     "yuki-yano/fern-preview.vim",
  --     "andykog/fern-highlight.vim",
  --     "lambdalisue/fern-hijack.vim",
  --     "lambdalisue/fern-git-status.vim",
  --     "lambdalisue/fern-renderer-nerdfont.vim",
  --     "lambdalisue/glyph-palette.vim",
  --     "lambdalisue/nerdfont.vim",
  --   },
  -- },
  { "nvim-neo-tree/neo-tree.nvim", enabled = false },
  -- neo-tree
  -- {
  -- neo-tree/neo-tree.nvim",
  --   dependencies = {
  --     "nvim-lua/ple enary.nvim",
  --     "nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
  --     "MunifTanjim/nui.nvim",
  --     "3rd/image.nvim",
  --   },
  --   opts = {
  --     filesystem = {
  --       filtered_items = {
  --         hide_dotfiles = false,
  --       },
  --       -- components = {
  --       --   harpoon_index = function(config, node, _)
  --       --     local harpoon_list = require("harpoon"):list()
  --       --     local path = node:get_id()
  --       --     local harpoon_key = vim.uv.cwd()
  --       --
  --       --     for i, item in ipairs(harpoon_list.items) do
  --       --       local value = item.value
  --       --       if string.sub(item.value, 1, 1) ~= "/" then
  --       --         value = harpoon_key .. "/" .. item.value
  --       --       end
  --       --
  --       --       if value == path then
  --       --         vim.print(path)
  --       --         return {
  --       --           text = string.format(" ⥤ %d", i), -- <-- Add your favorite harpoon like arrow here
  --       --           highlight = config.highlight or "NeoTreeDirectoryIcon",
  --       --         }
  --       --       end
  --       --     end
  --       --     return {}
  --       --   end,
  --       -- },
  --       -- renderers = {
  --       --   file = {
  --       --     { "icon" },
  --       --     { "name", use_git_status_colors = true },
  --       --     { "harpoon_index" }, --> This is what actually adds the component in where you want it
  --       --     { "diagnostics" },
  --       --     { "git_status", highlight = "NeoTreeDimText" },
  --       --   },
  --       -- },
  --     },
  --   },
  -- },
}
