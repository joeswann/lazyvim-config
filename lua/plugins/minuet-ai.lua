-- lua/plugins/minuet.lua  ← rename if you like
return {
  {
    "milanglacier/minuet-ai.nvim",
    lazy = false,
    config = function()
      require("minuet").setup({
        provider = "openai",

        provider_options = {
          gemini = {
            model = "gemini-2.0-flash", -- fast + long context
            stream = true, -- typing-style output
            api_key = "GEMINI_API_KEY", -- never hard-code
            end_point = "https://generativelanguage.googleapis.com/v1beta/models",
            -- leave out ↴  if you don’t need them; Minuet supplies defaults
            -- system      = "<your system prompt>",
            -- few_shots   = { { role = "user", content = "…" }, … },
            -- chat_input  = "<template>",
            optional = {}, -- extra Gemini args
          },

          openai = {
            model = "gpt-4.1-mini", -- current light GPT-4
            stream = true,
            api_key = "OPENAI_API_KEY",
            optional = {},
          },
        },

        -- opts.lsp = {
        --   enabled_ft = { "*" }, -- completions everywhere
        -- }
      })
    end,
  },
}
