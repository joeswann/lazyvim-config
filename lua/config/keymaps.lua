-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--

local map = vim.keymap.set

-- Quick save and quit
map("n", "<leader>w", ":w<CR>", { noremap = true, silent = true, desc = "Save file" })
map("n", "<leader>q", ":q<CR>", { noremap = true, silent = true, desc = "Quit" })

-- map("n", "<C-'>", "<cmd>Himalaya<cr>", { desc = "Email" })
map("", "<leader>'", require("oil").toggle_float, { desc = "Open navigator" })
map("", "<leader>e", require("nvim-tree.api").tree.toggle, { desc = "Open explorer" })
-- map("", "<Leader>l", require("lsp_lines").toggle, { desc = "Toggle lsp_lines" })

-- map("", "<leader>l", function()
--   require("trouble").toggle()
-- end, { desc = "Toggle trouble" })
--
-- vim.api.nvim_set_keymap("n", ":", ":", { noremap = true, silent = true })

-- Telescope keymaps
map("n", "<leader>bb", ":Telescope buffers<CR>", { noremap = true, silent = true, desc = "List buffers" })(
  "n",
  "<leader>r",
  ":Telescope resume<CR>",
  { noremap = true, silent = true, desc = "Resume last picker" }
)
