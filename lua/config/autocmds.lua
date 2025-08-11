-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
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

    local max_length = 50
    if #file_path > max_length then
      local path_parts = vim.split(file_path, "/")
      if #path_parts > 2 then
        file_path = path_parts[1] .. "/.../" .. path_parts[#path_parts]
      else
        file_path = table.concat(path_parts, "/")
      end
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
  local action_state = require("telescope.actions.state")

  telescope.extensions.fzf.files({
    prompt_title = "Navigate to Path",
    attach_mappings = function(prompt_bufnr, map)
      map("i", "<CR>", function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if selection and selection.path then
          vim.cmd("Oil " .. selection.path)
        end
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
