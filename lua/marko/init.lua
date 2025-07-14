local M = {}

-- Setup function for user configuration
function M.setup(opts)
  require('marko.config').setup(opts)
end

-- Main function to show marks popup
function M.show_marks()
  local popup = require("marko.popup")
  popup.create_popup()
end

-- Debug function to check marks
function M.debug_marks()
  local marks_module = require("marko.marks")
  marks_module.debug_marks()
end

return M
