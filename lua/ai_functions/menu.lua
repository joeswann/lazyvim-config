-- File: lua/functions/menu.lua
local M = {}

-- Initialize the available_functions table
M.available_functions = {}

-- Function to register a new function in the menu
function M.register_function(name, func, description)
  table.insert(M.available_functions, {
    name = name,
    func = func,
    description = description,
  })
end

-- Function to show the function menu
function M.show_function_menu()
  local items = {}
  for _, func_info in ipairs(M.available_functions) do
    table.insert(items, {
      name = func_info.name,
      description = func_info.description,
    })
  end

  vim.ui.select(items, {
    prompt = "Select function to execute:",
    format_item = function(item)
      return string.format("%s - %s", item.name, item.description)
    end,
  }, function(choice)
    if choice then
      for _, func_info in ipairs(M.available_functions) do
        if func_info.name == choice.name then
          func_info.func()
          break
        end
      end
    end
  end)
end

local function register_default_functions()
  local component = require("ai_functions.component")
  local formatter = require("ai_functions.formatter")

  M.register_function("Ask Claude", formatter.format_claude_response, "Process buffer with Claude")

  M.register_function("New Component", component.create_component_with_styles, "Create component")

  M.register_function("Component Template", component.replace_buffer_with_component, "Apply component template")
end

-- Initialize the menu system
register_default_functions()

return M
