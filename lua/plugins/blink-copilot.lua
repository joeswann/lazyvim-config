return {
  {
    "zbirenbaum/copilot.lua",
    event = "InsertEnter",
    opts = {
      suggestion = { enabled = false }, -- no ghost text
      panel = { enabled = false },
    },
  },
  {
    "giuxtaposition/blink-cmp-copilot",
    dependencies = { "Saghen/blink.cmp", "zbirenbaum/copilot.lua" },
  },
}
