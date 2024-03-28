-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--

local map = vim.keymap.set

map("n", "<C-'>", "<cmd>Himalaya<cr>", { desc = "Email" })
map("", "<Leader>l", require("lsp_lines").toggle, { desc = "Toggle lsp_lines" })
-- map("", "<Leader>e", ":Fern . -width=40 -toggle -drawer -reveal=%<cr>", { desc = "Toggle fern" })
map("", "<leader>e", require("oil").toggle_float, { desc = "Open explorer" })
