return {
  "ojroques/nvim-osc52",
  event = "VeryLazy",
  config = function()
    local function in_ssh()
      return vim.env.SSH_TTY ~= nil
    end

    if in_ssh() then
      vim.opt.clipboard:append("unnamedplus")
      require("osc52").setup({ max_length = 0, silent = true, trim = false })
    end
  end,
}
