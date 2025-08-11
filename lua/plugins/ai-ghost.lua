return {
  {
    "ai-ghost-local",
    dir = vim.fn.stdpath("config") .. "/lua/ai_core",
    event = "InsertEnter",
    config = function()
      if vim.g.ai_ghost_fallback then
        require("ai_core.ghost").setup({ debounce_ms = 180 })
      end
    end,
  },
}
