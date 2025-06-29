-- ~/.config/nvim/lua/clipboard.lua
local function in_ssh()
  return vim.env.SSH_TTY ~= nil
end

if in_ssh() then
  -- comment out ONE of the blocks below
  ----------------------------------------------------------------------
  -- 1. Disable clipboard completely -------------------------------
  -- vim.opt.clipboard = ''

  ----------------------------------------------------------------------
  -- 2. Use OSC52 (recommended) -------------------------------------
  vim.opt.clipboard:append("unnamedplus")
  require("osc52").setup({
    max_length = 0, -- no size limit
    silent = true, -- no messages
    trim = false, -- keep trailing newline
  })
end
