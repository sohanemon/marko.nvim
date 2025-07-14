local M = {}

-- Setup function for user configuration
function M.setup(opts)
  -- Setup configuration and highlights
  require('marko.config').setup(opts)
  
  -- Setup syntax highlighting for the popup filetype
  require('marko.syntax').setup_filetype()
  
  -- Setup virtual text marks
  local config = require('marko.config').get()
  if config.virtual_text then
    require('marko.virtual').setup(config.virtual_text)
    require('marko.virtual').setup_autocmds()
  end
  
  -- Setup default keymap if enabled
  if config.default_keymap then
    vim.keymap.set('n', config.default_keymap, function()
      M.toggle_marks()
    end, { desc = 'Toggle marks popup' })
  end
  
  -- Setup autocommands for theme changes
  vim.api.nvim_create_autocmd("ColorScheme", {
    callback = function()
      require('marko.config').refresh_highlights()
    end,
    group = vim.api.nvim_create_augroup("MarkoColorScheme", { clear = true })
  })
end

-- Main function to toggle marks popup
function M.toggle_marks()
  local popup = require("marko.popup")
  if popup.is_open() then
    popup.close_popup()
  else
    popup.create_popup()
  end
end

-- Main function to show marks popup (kept for compatibility)
function M.show_marks()
  local popup = require("marko.popup")
  popup.create_popup()
end

-- Debug function to check marks
function M.debug_marks()
  local marks_module = require("marko.marks")
  marks_module.debug_marks()
end

-- Function to refresh highlights (useful for theme changes)
function M.refresh_highlights()
  require('marko.config').refresh_highlights()
end

-- Toggle virtual text marks on/off
function M.toggle_virtual_marks()
  require('marko.virtual').toggle()
end

-- Refresh virtual marks in current buffer
function M.refresh_virtual_marks()
  require('marko.virtual').refresh_buffer_marks()
end

return M
