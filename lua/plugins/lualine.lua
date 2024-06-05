return {
  "nvim-lualine/lualine.nvim",
  opts = function(_, opts)
    local sections = opts.sections
    sections.lualine_c = {
      {
        "filename",
        path = 1, -- Display the relative path
        symbols = { modified = "  ", readonly = "", unnamed = "" },
      },
    }
  end,
}
