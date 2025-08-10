return {
  {
    "saghen/blink.cmp",
    opts = function(_, opts)
      opts.keymap = opts.keymap or {}
      -- use any preset you like; "enter" avoids LazyVim's super-tab hook path
      opts.keymap.preset = opts.keymap.preset or "enter"

      -- provide <Tab>/<S-Tab> yourself so LazyVim doesn't try to read the preset internals
      opts.keymap["<Tab>"] = {
        function(cmp)
          if cmp.snippet_active() then
            return cmp.accept()
          else
            return cmp.select_and_accept()
          end
        end,
        "snippet_forward",
        -- if you use LazyVim’s AI accept hook, keep it; otherwise remove this line:
        require("lazyvim.util.cmp").map({ "ai_accept" }),
        "fallback",
      }
      opts.keymap["<S-Tab>"] = { "snippet_backward", "fallback" }
    end,
  },
}
