-- ~/.config/nvim/lua/plugins/telescope.lua

return {
  "nvim-telescope/telescope.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    local telescope = require("telescope")
    local builtin = require("telescope.builtin")

    telescope.setup({
      defaults = {
        mappings = {
          i = {
            ["<C-j>"] = "move_selection_next",
            ["<C-k>"] = "move_selection_previous",
          },
        },
      },
      pickers = {
        buffers = {
          show_all_buffers = true,
          sort_lastused = true,
          theme = "dropdown",
          previewer = false,
          mappings = {
            i = {
              ["<C-d>"] = "delete_buffer",
            },
          },
        },
      },
    })

    -- Custom find_files function that always starts from git root
    local function find_files_from_root()
      -- Get the git root directory
      local git_root = vim.fn.system("git rev-parse --show-toplevel 2> /dev/null"):gsub("\n", "")
      if git_root ~= "" then
        builtin.find_files({ cwd = git_root })
      else
        -- Fallback to current working directory if not in a git repository
        builtin.find_files()
      end
    end

    -- Set up the keymapping for find_files
    vim.keymap.set("n", "<leader><leader>", find_files_from_root, { noremap = true, silent = true })
  end,
}
