local M = {}

-- Import submodules
local component = require("functions.component")
local formatter = require("functions.formatter")
local menu = require("functions.menu")

-- Re-export component functions
M.replace_buffer_with_component = component.replace_buffer_with_component
M.create_component_with_styles = component.create_component_with_styles

-- Re-export formatter functions
M.format_claude_response = formatter.format_claude_response

-- Re-export menu functionality
M.show_function_menu = menu.show_function_menu
M.available_functions = menu.available_functions

return M
