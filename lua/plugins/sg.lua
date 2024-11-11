return {
  {
    "nvim-cmp",
    dependencies = { "sourcegraph/sg.nvim" },
    opts = function(_, opts)
      table.insert(opts.sources, 1, { name = "cody" })
    end,
  },
  {
    "sourcegraph/sg.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
    },
    opts = function()
      local sg = require("sg")

      -- Single command that handles the selection automatically
      vim.api.nvim_create_user_command("CodyTaskSmart", function()
        -- Select whole file if no selection exists
        if vim.fn.mode() == "n" then
          vim.cmd("normal! ggVG")
        end

        local prompt = vim.fn.input("Cody Task: ")
        if prompt ~= "" then
          vim.cmd("'<,'>CodyTask " .. vim.fn.escape(prompt, " "))
        end
      end, { range = true })

      -- Single keymap for both modes
      vim.api.nvim_set_keymap("n", "<leader>cp", ":CodyTaskSmart<CR>", { noremap = true, silent = true })
      vim.api.nvim_set_keymap("v", "<leader>cp", ":CodyTaskSmart<CR>", { noremap = true, silent = true })

      sg.setup({
        enable_cody = true,
        accept_tos = true,
      })
    end,
  },
}
