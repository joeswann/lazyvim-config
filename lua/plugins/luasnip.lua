return {
  {
    "L3MON4D3/LuaSnip",
    version = "v2.*",
    event = "InsertEnter",
    -- optional: enable JS regex for nicer snippet regex (non-Windows)
    build = (vim.loop.os_uname().sysname == "Windows_NT") and nil or "make install_jsregexp",
    dependencies = {
      {
        "rafamadriz/friendly-snippets",
        -- config = function()
        --   require("luasnip.loaders.from_vscode").lazy_load()
        -- end,
      },
    },
    config = function()
      local ls = require("luasnip")

      -- Make snippets refresh as you type
      ls.config.set_config({
        history = true,
        updateevents = "TextChanged,TextChangedI", -- <- key line
        region_check_events = "CursorHold,InsertEnter",
        delete_check_events = "TextChanged,TextChangedI",
        enable_autosnippets = true, -- optional, if you use autosnips
      })

      -- Load your Lua snippets
      require("luasnip.loaders.from_lua").lazy_load({
        paths = vim.fn.stdpath("config") .. "/lua/snippets",
      })

      -- (Optional) also load VSCode-style packs
      -- require("luasnip.loaders.from_vscode").lazy_load()
    end,
  },
}
