return {
  {
    "f-person/git-blame.nvim",
    event = "BufReadPre",
    config = function()
      vim.cmd("highlight default link gitblame SpecialComment")
      vim.g.gitblame_enabled = 0
    end,
  },
}