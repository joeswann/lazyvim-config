-- delegates to ai_engine/core so all Claude calls are centralized
local M = {}
local core = require("ai_core.core")

function M.format_text(text, prompt, context, callback)
  if not text or text == "" then
    return callback({ success = false, message = "No text provided" })
  end
  core.edit(text, prompt, context, function(res)
    if not res.success then
      return callback(res)
    end
    callback(res)
  end)
end

return M
