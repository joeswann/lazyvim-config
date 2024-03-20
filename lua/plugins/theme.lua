return { -- add gruvbox

  { "ellisonleao/gruvbox.nvim" },

  -- configure LazyVim to load gruvbox
  {
    "lazyVim/LazyVim",
    opts = {
      colorscheme = "gruvbox",
    },
  },
}
