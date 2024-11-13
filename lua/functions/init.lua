local M = {}

-- Function to get component name from current buffer if it exists
local function get_current_component_name()
  local current_file = vim.fn.expand("%:t")
  if current_file == "" then
    return nil
  end
  return current_file:match("^(.+)%.[^.]+$") -- Matches filename without extension
end

-- Function to create React component content
local function create_react_content(component_name)
  return string.format(
    [[
import { DefaultComponentInterface } from "~/types/components";
import styles from "./%s.module.scss";
import classNames from "classnames";

const %s: DefaultComponentInterface = ({ className }) => {
 return (
   <div className={classNames(className, styles.container)}>
   </div>
 );
};

export default %s;
]],
    component_name,
    component_name,
    component_name
  )
end

-- Function to create SCSS module content
local function create_scss_content()
  return [[
@import "~/styles/helpers";

.container {
 
}
]]
end

-- Function to create a new React component
M.create_react_component = function(component_name)
  if not component_name then
    vim.ui.input({ prompt = "Component name: " }, function(name)
      if name then
        M.create_react_component(name)
      end
    end)
    return
  end

  local content = create_react_content(component_name)
  local current_ft = vim.bo.filetype

  if current_ft == "typescript" or current_ft == "typescriptreact" then
    -- Replace current buffer content
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))
  else
    -- Create new buffer
    vim.cmd("enew")
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))
    vim.bo[buf].filetype = "typescript"
    vim.cmd(string.format("write %s.tsx", component_name))
  end

  -- Position cursor inside the div
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  for i, line in ipairs(lines) do
    if line:match("^%s*<div") then
      vim.api.nvim_win_set_cursor(0, { i + 1, 6 })
      break
    end
  end
end

-- Function to create a SCSS module
M.create_scss_module = function(component_name)
  if not component_name then
    vim.ui.input({ prompt = "Component name: " }, function(name)
      if name then
        M.create_scss_module(name)
      end
    end)
    return
  end

  local content = create_scss_content()
  local current_ft = vim.bo.filetype

  if current_ft == "scss" then
    -- Replace current buffer content
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))
  else
    -- Create new buffer
    vim.cmd("enew")
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))
    vim.bo[buf].filetype = "scss"
    vim.cmd(string.format("write %s.module.scss", component_name))
  end

  -- Position cursor inside container
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  for i, line in ipairs(lines) do
    if line:match("^%.container {") then
      vim.api.nvim_win_set_cursor(0, { i + 1, 2 })
      break
    end
  end
end

-- Function to create both React component and SCSS module
M.create_component_with_styles = function()
  vim.ui.input({ prompt = "Component name: " }, function(component_name)
    if not component_name then
      return
    end
    M.create_react_component(component_name)
    M.create_scss_module(component_name)
    -- Return to the React component buffer
    vim.cmd(string.format("edit %s.tsx", component_name))
  end)
end

-- Function to create or replace current buffer
M.replace_current_buffer = function()
  local current_file = vim.fn.expand("%:t")
  local component_name = get_current_component_name()

  if not component_name then
    return M.show_function_menu()
  end

  if current_file:match("%.tsx$") then
    M.create_react_component(component_name)
  elseif current_file:match("%.module%.scss$") then
    M.create_scss_module(component_name)
  else
    M.show_function_menu()
  end
end

-- Table of available functions with descriptions
M.available_functions = {
  {
    name = "Create React Component",
    func = M.create_react_component,
    description = "Create a new React component",
  },
  {
    name = "Create SCSS Module",
    func = M.create_scss_module,
    description = "Create a new styling module",
  },
  {
    name = "Create Component with Styles",
    func = M.create_component_with_styles,
    description = "Create both React component and SCSS module",
  },
  {
    name = "Replace Current Buffer",
    func = M.replace_current_buffer,
    description = "Replace current buffer with template",
  },
}

M.show_function_menu = function()
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

return M
