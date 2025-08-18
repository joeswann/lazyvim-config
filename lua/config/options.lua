-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.softtabstop = 2
vim.opt.number = true
vim.opt.relativenumber = false

-- AI provider configuration
-- Options: "claude", "gemini", "auto" (auto selects based on available API keys)
vim.g.ai_provider = "gemini"

-- Enable verbose logging for debugging
vim.lsp.set_log_level("debug")
