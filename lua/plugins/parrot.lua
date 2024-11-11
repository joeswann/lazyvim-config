return {
  {
    "frankroeder/parrot.nvim",
    dependencies = { "ibhagwan/fzf-lua", "nvim-lua/plenary.nvim", "rcarriga/nvim-notify" },
    config = function()
      require("parrot").setup({
        providers = {
          anthropic = {
            api_key = os.getenv("ANTHROPIC_API_KEY"),
          },
          openai = {
            api_key = os.getenv("OPENAI_API_KEY"),
          },
          github = {
            api_key = os.getenv("GITHUB_TOKEN"),
          },
        },
      })
    end,
  },
}
