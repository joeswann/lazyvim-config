-- File: lua/functions/component.lua
local M = {}

local utils = require("ai_functions.utils")

-- Function to create React component content
local function create_react_content(component_name)
  return string.format(
    [[
import styles from "./%s.module.scss";
import { DCI } from "~/types/DCI";
import cn from "classnames";

const %s: DCI = ({ className }) => {
 return (
   <div className={cn(className, styles.container)}>
      
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

-- Function to create css module content
local function create_css_content()
  return [[
@import "~/styles/_helpers";

.container {
 
}
]]
end

-- Function to normalize path
local function normalize_path(path)
  -- Replace multiple slashes with single slash
  path = path:gsub("//+", "/")

  -- Ensure relative paths start with ./
  if not path:match("^[/.]") then
    path = "./" .. path
  end

  return path
end

-- Function to split path and component name
local function split_path_and_name(combined_path)
  -- Remove trailing .tsx or .module.css if present
  local base_path = combined_path:gsub("%.tsx$", ""):gsub("%.module%.css$", "")

  -- Extract the component name (last part after / that starts with capital letter)
  local path, name = base_path:match("(.*/)?([A-Z][%w_]*)$")

  -- Handle cases with no path prefix
  if not path and base_path:match("^[A-Z]") then
    name = base_path
    path = "./"
  end

  if not name then
    return nil, nil
  end

  -- Handle absolute paths and normalize
  if combined_path:match("^/") then
    path = "/"
  elseif not path then
    path = "./"
  end

  path = normalize_path(path)

  -- Check if original path had specific file extension
  local create_tsx = not combined_path:match("%.module%.css$")
  local create_css = not combined_path:match("%.tsx$")

  return path, name, create_tsx, create_css
end

-- Function to create and save component files
local function create_component_files(path, component_name, create_tsx, create_css)
  -- Get the current buffer's directory
  local current_dir = vim.fn.expand("%:p:h")

  -- Handle absolute paths and relative paths
  local full_path
  if path:match("^/") then
    full_path = path
  else
    -- If path starts with ./ or ../, make it relative to current buffer's directory
    full_path = path:match("^%.") and vim.fn.simplify(current_dir .. "/" .. path) or path
  end

  -- Ensure path ends with /
  full_path = full_path:gsub("/?$", "/")
  full_path = normalize_path(full_path)

  -- Create the full paths
  local tsx_path = full_path .. component_name .. ".tsx"
  local css_path = full_path .. component_name .. ".module.css"

  -- Create the component directory if it doesn't exist
  vim.fn.mkdir(vim.fn.fnamemodify(tsx_path, ":h"), "p")

  -- Create and write the TSX file if requested
  if create_tsx then
    local tsx_file = io.open(tsx_path, "w")
    if tsx_file then
      tsx_file:write(create_react_content(component_name))
      tsx_file:close()
    end
  end

  -- Create and write the css file if requested
  if create_css then
    local css_file = io.open(css_path, "w")
    if css_file then
      css_file:write(create_css_content())
      css_file:close()
    end
  end

  return tsx_path, css_path
end

-- Function to add import statement at the top of the file
local function add_import_statement(component_name, component_path)
  -- Get the current buffer's directory
  local current_dir = vim.fn.expand("%:p:h")

  -- Convert the absolute component path to a path relative to the current file
  local relative_path = vim.fn.fnamemodify(component_path, ":p"):gsub(current_dir .. "/", "./")
  relative_path = relative_path:gsub("%.tsx$", "") -- Remove .tsx extension
  relative_path = normalize_path(relative_path) -- Normalize the path

  -- Get current buffer content
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  -- Find the last import statement
  local last_import_line = 0
  for i, line in ipairs(lines) do
    if line:match("^import") then
      last_import_line = i
    end
  end

  -- Create import statement for default import
  local import_statement = string.format('import %s from "%s";', component_name, relative_path)

  -- Insert the import statement after the last import
  if last_import_line > 0 then
    vim.api.nvim_buf_set_lines(0, last_import_line, last_import_line, false, { import_statement })
  else
    vim.api.nvim_buf_set_lines(0, 0, 0, false, { import_statement, "" })
  end
end

-- Function to insert component at cursor
local function insert_component_at_cursor(component_name)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local current_line = vim.api.nvim_get_current_line()

  -- Insert the component tag
  local component_tag = string.format("<%s />", component_name)
  local new_line = current_line:sub(1, col) .. component_tag .. current_line:sub(col + 1)

  vim.api.nvim_set_current_line(new_line)
  vim.api.nvim_win_set_cursor(0, { row, col + #component_tag })
end

-- Function to create component with styles and insert at cursor
function M.create_component_with_styles()
  vim.ui.input({ prompt = "Component path and name (e.g. ./items/MenuItem): " }, function(combined_path)
    if not combined_path then
      return
    end

    -- Split the input into path and component name
    local path, component_name, create_tsx, create_css = split_path_and_name(combined_path)

    if not path or not component_name then
      utils.show_toast("Invalid input. Must include a capitalized component name", "error")
      return
    end

    -- Create the component files
    local tsx_path, _ = create_component_files(path, component_name, create_tsx, create_css)

    -- Only add import and insert component if we created a TSX file
    if create_tsx then
      -- Add import statement
      add_import_statement(component_name, tsx_path)

      -- Insert component at cursor
      insert_component_at_cursor(component_name)
    end

    -- Show success notification
    local files_created = create_tsx and create_css and "TSX and css files" or create_tsx and "TSX file" or "css file"
    utils.show_toast(string.format("Created %s for %s", files_created, component_name), "info")
  end)
end

-- Function to replace current buffer with component template
function M.replace_buffer_with_component()
  local component_name = utils.get_current_component_name()
  if not component_name then
    utils.show_toast("No valid component name found", "error")
    return
  end

  local current_file = vim.fn.expand("%:t")
  if current_file:match("%.tsx$") then
    local content = create_react_content(component_name)
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))
    utils.set_cursor_after_pattern("^%s*<div")
  elseif current_file:match("%.module%.css$") then
    local content = create_css_content()
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))
    utils.set_cursor_after_pattern("^%.container {")
  else
    utils.show_toast("Current file is not a component or style module", "error")
  end
end

return M
