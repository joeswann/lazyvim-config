-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

vim.api.nvim_create_autocmd("FileType", {
  pattern = "oil",
  callback = function()
    vim.api.nvim_buf_set_keymap(0, "n", "<C-cr>", ":lua OilNavigate()<CR>", { noremap = true, silent = true })
  end,
})

vim.api.nvim_create_autocmd({ "BufEnter", "BufFilePost" }, {
  callback = function()
    local file_path = vim.fn.expand("%:.")
    local git_repo = vim.fn.system("git rev-parse --show-toplevel"):gsub("[\n\r]+", "")
    local repo_name = vim.fn.fnamemodify(git_repo, ":t")

    -- Shorten the file path if it exceeds a certain length
    local max_length = 50
    if #file_path > max_length then
      local path_parts = vim.split(file_path, "/")
      local shortened_path = ""

      if #path_parts > 2 then
        shortened_path = path_parts[1] .. "/.../" .. path_parts[#path_parts]
      else
        shortened_path = table.concat(path_parts, "/")
      end

      file_path = shortened_path
    end

    vim.opt.titlestring = repo_name .. " - " .. file_path
    vim.cmd("let &titleold = &title")
    vim.cmd("set title")
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

vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.py",
  callback = function()
    vim.cmd([[retab]])
  end,
})
