-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/ladzyvim/config/autocmds.lua
-- Add any additional autocmds here

vim.api.nvim_create_autocmd("FileType", {
  pattern = "oil",
  callback = function()
    vim.api.nvim_buf_set_keymap(0, "n", "<C-cr>", ":lua OilNavigate()<CR>", { noremap = true, silent = true })
  end,
})

vim.api.nvim_create_autocmd("CursorHold", {
  callback = function()
    vim.diagnostic.open_float({ scope = "line" })
  end,
})

function OilNavigate()
  local telescope = require("telescope")
  local actions = require("telescope.actions")

  telescope.extensions.fzf.files({
    prompt_title = "Navigate to Path",
    attach_mappings = function(prompt_bufnr, map)
      map("i", "<CR>", function()
        local selection = actions.get_selected_entry()
        actions.close(prompt_bufnr)
        vim.cmd("Oil " .. selection.path)
      end)
      return true
    end,
  })
end
