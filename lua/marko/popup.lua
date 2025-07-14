local M = {}

local popup_buf = nil
local popup_win = nil

-- Create the popup window
function M.create_popup()
  local config = require("marko.config").get()
  local marks = require("marko.marks").get_all_marks()
  
  -- Close existing popup if open
  if popup_win and vim.api.nvim_win_is_valid(popup_win) then
    vim.api.nvim_win_close(popup_win, true)
  end
  
  -- Create buffer
  popup_buf = vim.api.nvim_create_buf(false, true)
  
  -- Set buffer options
  vim.api.nvim_buf_set_option(popup_buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(popup_buf, "filetype", "marks-popup")
  
  -- Calculate window size and position
  local width = config.width
  local height = math.min(config.height, #marks + 2)
  local row = math.ceil((vim.o.lines - height) / 2)
  local col = math.ceil((vim.o.columns - width) / 2)
  
  -- Create window
  popup_win = vim.api.nvim_open_win(popup_buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    border = config.border,
    title = config.title,
    title_pos = "center",
    style = "minimal",
  })
  
  -- Set window options
  vim.api.nvim_win_set_option(popup_win, "winhl", "Normal:Normal,FloatBorder:FloatBorder")
  
  -- Populate buffer with marks
  M.populate_buffer(marks)
  
  -- Set up keymaps
  M.setup_keymaps()
end

-- Populate buffer with marks data
function M.populate_buffer(marks)
  local lines = {}
  
  if #marks == 0 then
    table.insert(lines, "No marks found")
  else
    for i, mark in ipairs(marks) do
      local line_str
      if mark.type == "global" then
        local filename = vim.fn.fnamemodify(mark.filename, ":t")
        line_str = string.format("%s  %4d  %s  %s", 
          mark.mark, mark.line, filename, mark.text)
      else
        line_str = string.format("%s  %4d  %s", 
          mark.mark, mark.line, mark.text)
      end
      table.insert(lines, line_str)
    end
  end
  
  vim.api.nvim_buf_set_lines(popup_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(popup_buf, "modifiable", false)
  
  -- Store marks data in buffer variable for keymap access
  vim.b[popup_buf].marks_data = marks
end

-- Set up keymaps for the popup
function M.setup_keymaps()
  local config = require("marko.config").get()
  local marks_module = require("marko.marks")
  
  -- Close popup
  vim.keymap.set("n", config.keymaps.close, function()
    M.close_popup()
  end, { buffer = popup_buf, silent = true })
  
  -- Go to mark
  vim.keymap.set("n", config.keymaps.goto, function()
    local line = vim.api.nvim_win_get_cursor(0)[1]
    local marks_data = vim.b[popup_buf].marks_data
    
    if marks_data and marks_data[line] then
      M.close_popup()
      marks_module.goto_mark(marks_data[line])
    end
  end, { buffer = popup_buf, silent = true })
  
  -- Delete mark
  vim.keymap.set("n", config.keymaps.delete, function()
    local line = vim.api.nvim_win_get_cursor(0)[1]
    local marks_data = vim.b[popup_buf].marks_data
    
    if marks_data and marks_data[line] then
      marks_module.delete_mark(marks_data[line])
      -- Refresh the popup
      vim.defer_fn(function()
        M.create_popup()
      end, 50)
    end
  end, { buffer = popup_buf, silent = true })
end

-- Close the popup
function M.close_popup()
  if popup_win and vim.api.nvim_win_is_valid(popup_win) then
    vim.api.nvim_win_close(popup_win, true)
  end
  popup_win = nil
  popup_buf = nil
end

return M
