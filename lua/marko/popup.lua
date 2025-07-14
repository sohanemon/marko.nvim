local M = {}

local popup_buf = nil
local popup_win = nil
local shadow_win = nil

-- Create shadow window for depth effect
local function create_shadow(width, height, row, col)
  if not require("marko.config").get().shadow then
    return nil
  end
  
  local shadow_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(shadow_buf, "bufhidden", "wipe")
  
  local shadow_win = vim.api.nvim_open_win(shadow_buf, false, {
    relative = "editor",
    width = width,
    height = height,
    row = row + 1,
    col = col + 2,
    style = "minimal",
    focusable = false,
    zindex = 1  -- Behind main window
  })
  
  -- Set shadow appearance
  vim.api.nvim_win_set_option(shadow_win, "winhl", "Normal:Normal")
  vim.api.nvim_win_set_option(shadow_win, "winblend", 80)
  
  return shadow_win
end

-- Create the popup window
function M.create_popup()
  local config = require("marko.config").get()
  local marks = require("marko.marks").get_all_marks()
  
  -- Close existing popup if open
  if popup_win and vim.api.nvim_win_is_valid(popup_win) then
    vim.api.nvim_win_close(popup_win, true)
  end
  if shadow_win and vim.api.nvim_win_is_valid(shadow_win) then
    vim.api.nvim_win_close(shadow_win, true)
  end
  
  -- Create buffer
  popup_buf = vim.api.nvim_create_buf(false, true)
  
  -- Set buffer options
  vim.api.nvim_buf_set_option(popup_buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(popup_buf, "filetype", "marko-popup")
  
  -- Calculate window size and position
  local width = config.width
  local height = math.min(config.height, #marks + 2)
  local row = math.ceil((vim.o.lines - height) / 2)
  local col = math.ceil((vim.o.columns - width) / 2)
  
  -- Create shadow window first (if enabled)
  shadow_win = create_shadow(width, height, row, col)
  
  -- Create main window
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
    zindex = 2  -- Above shadow
  })
  
  -- Set window options with custom highlights
  local winhl = "Normal:MarkoNormal,FloatBorder:MarkoBorder,CursorLine:MarkoCursorLine"
  vim.api.nvim_win_set_option(popup_win, "winhl", winhl)
  
  -- Set transparency if configured
  if config.transparency > 0 then
    vim.api.nvim_win_set_option(popup_win, "winblend", config.transparency)
  end
  
  -- Enable cursor line highlighting
  vim.api.nvim_win_set_option(popup_win, "cursorline", true)
  
  -- Populate buffer with marks
  M.populate_buffer(marks)
  
  -- Set up keymaps
  M.setup_keymaps()
end

-- Populate buffer with marks data
function M.populate_buffer(marks)
  local config = require("marko.config").get()
  local ns_id = require("marko.config").get_namespace()
  local lines = {}
  
  if #marks == 0 then
    table.insert(lines, "No marks found")
  else
    for i, mark in ipairs(marks) do
      local icon = mark.type == "global" and config.icons.global or config.icons.buffer
      local filename = ""
      
      if mark.type == "global" and mark.filename then
        filename = vim.fn.fnamemodify(mark.filename, ":t")
        -- Truncate long filenames
        if #filename > config.columns.filename then
          filename = filename:sub(1, config.columns.filename - 3) .. "..."
        end
      end
      
      -- Create formatted line with proper spacing
      local line_str
      if mark.type == "global" then
        line_str = string.format("%s %s %s %s %4d %s %-" .. config.columns.filename .. "s %s %s", 
          icon,
          config.icons.separator,
          mark.mark,
          config.icons.line,
          mark.line,
          config.icons.file,
          filename,
          config.icons.separator,
          mark.text:sub(1, 50)
        )
      else
        line_str = string.format("%s %s %s %s %4d %s %s", 
          icon,
          config.icons.separator,
          mark.mark,
          config.icons.line,
          mark.line,
          config.icons.separator,
          mark.text:sub(1, 50)
        )
      end
      
      table.insert(lines, line_str)
    end
  end
  
  vim.api.nvim_buf_set_lines(popup_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(popup_buf, "modifiable", false)
  
  -- Store marks data in buffer variable for keymap access
  vim.b[popup_buf].marks_data = marks
  
  -- Apply syntax highlighting
  M.apply_highlighting(marks)
end

-- Apply highlighting to the buffer content
function M.apply_highlighting(marks)
  local config = require("marko.config").get()
  local ns_id = require("marko.config").get_namespace()
  
  -- Clear existing highlights
  vim.api.nvim_buf_clear_namespace(popup_buf, ns_id, 0, -1)
  
  if #marks == 0 then
    -- Highlight "No marks found" message
    vim.api.nvim_buf_set_extmark(popup_buf, ns_id, 0, 0, {
      end_col = -1,
      hl_group = "MarkoContent"
    })
    return
  end
  
  for i, mark in ipairs(marks) do
    local line_idx = i - 1
    local col = 0
    
    -- Highlight mark type icon
    vim.api.nvim_buf_set_extmark(popup_buf, ns_id, line_idx, col, {
      end_col = col + vim.fn.strchars(config.icons[mark.type]),
      hl_group = "MarkoIcon"
    })
    col = col + vim.fn.strchars(config.icons[mark.type]) + 1
    
    -- Highlight first separator
    vim.api.nvim_buf_set_extmark(popup_buf, ns_id, line_idx, col, {
      end_col = col + vim.fn.strchars(config.icons.separator),
      hl_group = "MarkoSeparator"
    })
    col = col + vim.fn.strchars(config.icons.separator) + 1
    
    -- Highlight mark character
    local mark_hl = mark.type == "global" and "MarkoGlobalMark" or "MarkoBufferMark"
    vim.api.nvim_buf_set_extmark(popup_buf, ns_id, line_idx, col, {
      end_col = col + 1,
      hl_group = mark_hl
    })
    col = col + 2
    
    -- Highlight line icon
    vim.api.nvim_buf_set_extmark(popup_buf, ns_id, line_idx, col, {
      end_col = col + vim.fn.strchars(config.icons.line),
      hl_group = "MarkoIcon"
    })
    col = col + vim.fn.strchars(config.icons.line) + 1
    
    -- Highlight line number
    local line_num_str = string.format("%4d", mark.line)
    vim.api.nvim_buf_set_extmark(popup_buf, ns_id, line_idx, col, {
      end_col = col + #line_num_str,
      hl_group = "MarkoLineNumber"
    })
    col = col + #line_num_str + 1
    
    if mark.type == "global" then
      -- Highlight file icon
      vim.api.nvim_buf_set_extmark(popup_buf, ns_id, line_idx, col, {
        end_col = col + vim.fn.strchars(config.icons.file),
        hl_group = "MarkoIcon"
      })
      col = col + vim.fn.strchars(config.icons.file) + 1
      
      -- Highlight filename
      local filename = vim.fn.fnamemodify(mark.filename or "", ":t")
      if #filename > config.columns.filename then
        filename = filename:sub(1, config.columns.filename - 3) .. "..."
      end
      if #filename > 0 then
        vim.api.nvim_buf_set_extmark(popup_buf, ns_id, line_idx, col, {
          end_col = col + config.columns.filename,
          hl_group = "MarkoFilename"
        })
        col = col + config.columns.filename + 1
      end
    end
    
    -- Find and highlight final separator
    local line_content = vim.api.nvim_buf_get_lines(popup_buf, line_idx, line_idx + 1, false)[1]
    if line_content then
      local sep_pos = line_content:find(config.icons.separator .. "%s*[^" .. config.icons.separator .. "]*$")
      if sep_pos then
        vim.api.nvim_buf_set_extmark(popup_buf, ns_id, line_idx, sep_pos - 1, {
          end_col = sep_pos,
          hl_group = "MarkoSeparator"
        })
        
        -- Highlight content after final separator
        vim.api.nvim_buf_set_extmark(popup_buf, ns_id, line_idx, sep_pos + 1, {
          end_col = -1,
          hl_group = "MarkoContent"
        })
      end
    end
  end
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
  if shadow_win and vim.api.nvim_win_is_valid(shadow_win) then
    vim.api.nvim_win_close(shadow_win, true)
  end
  popup_win = nil
  popup_buf = nil
  shadow_win = nil
end

return M
