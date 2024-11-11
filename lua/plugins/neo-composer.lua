return {
  {
    "ecthelionvi/NeoComposer.nvim",
    dependencies = {
      "kkharji/sqlite.lua",
      "stevearc/oil.nvim",
      "nvim-telescope/telescope.nvim",
    },
    opts = {
      notify = true,
      keymaps = {
        play_macro = "Q",
        yank_macro = "yq",
        stop_macro = "cq",
        toggle_record = "q",
        cycle_next = "<c-n>",
        cycle_prev = "<c-p>",
        toggle_macro_menu = "<m-q>",
      },
    },
    config = function()
      local composer = require("NeoComposer")
      composer.setup()

      -- Predefined AI command macros
      local ai_macros = {
        {
          name = "Add Types to File",
          register = "t",
          command = [[ggVG:CodyTask Add TypeScript types to this file, ensuring full type safety while maintaining the existing logic.<CR>]],
        },
        {
          name = "Document Function",
          register = "d",
          command = [[V:CodyTask Add JSDoc documentation to this function, including param types, return type, and a clear description.<CR>]],
        },
        {
          name = "Optimize Code",
          register = "o",
          command = [[ggVG:CodyTask Optimize this code for better performance while maintaining readability. Include comments explaining the optimizations.<CR>]],
        },
        {
          name = "Add Error Handling",
          register = "e",
          command = [[ggVG:CodyTask Add comprehensive error handling to this code, including try-catch blocks and appropriate error messages.<CR>]],
        },
        {
          name = "Add Tests",
          register = "u",
          command = [[ggVG:CodyTask Generate comprehensive unit tests for this code using the appropriate testing framework.<CR>]],
        },
        {
          name = "Refactor Code",
          register = "r",
          command = [[ggVG:CodyTask Refactor this code to improve its structure, maintainability, and adherence to best practices.<CR>]],
        },
      }

      -- Store React className macro
      local react_classname_macro =
        [[:silent! /props<CR>ciw{ className, ...props }<ESC>/<div<CR>f>i className={classNames(className)}<ESC>]]
      vim.fn.setreg("c", react_classname_macro)

      -- Function to show macro picker with Telescope
      local function show_ai_macro_picker()
        local pickers = require("telescope.pickers")
        local finders = require("telescope.finders")
        local conf = require("telescope.config").values
        local actions = require("telescope.actions")
        local action_state = require("telescope.actions.state")

        pickers
          .new({}, {
            prompt_title = "AI Commands",
            finder = finders.new_table({
              results = ai_macros,
              entry_maker = function(entry)
                return {
                  value = entry,
                  display = entry.name,
                  ordinal = entry.name,
                }
              end,
            }),
            sorter = conf.generic_sorter({}),
            attach_mappings = function(prompt_bufnr, _)
              actions.select_default:replace(function()
                actions.close(prompt_bufnr)
                local selection = action_state.get_selected_entry()
                local macro = selection.value
                -- Execute the selected macro's command
                vim.cmd("normal! " .. macro.command)
              end)
              return true
            end,
          })
          :find()
      end

      -- Map a key to access the AI macro picker
      vim.keymap.set("n", "<leader>ma", show_ai_macro_picker, { desc = "Show AI Macros" })

      -- Map original React className macro
      vim.keymap.set("n", "<leader>mc", function()
        vim.fn.execute("normal! @c")
      end, { desc = "Apply React className macro" })
    end,
  },
}
