local M = {}

local popup_buf = nil
local popup_win = nil
local shadow_win = nil

-- Check if popup is currently open
function M.is_open()
  return popup_win and vim.api.nvim_win_is_valid(popup_win)
end

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
      local filename = ""
      
      -- Get filename for all marks (not just global)
      if mark.filename then
        filename = vim.fn.fnamemodify(mark.filename, ":~:.")  -- Relative to cwd
      elseif mark.type == "buffer" then
        filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":~:.")  -- Current buffer
      end
      
      -- Truncate long filenames
      if #filename > config.columns.filename then
        filename = filename:sub(1, config.columns.filename - 3) .. "..."
      end
      
      -- Create formatted line with tight spacing
      local line_str = string.format("%s%s%4d%s%s%s%s", 
        mark.mark,
        config.separator,
        mark.line,
        config.separator,
        filename,
        config.separator,
        mark.text:sub(1, 50)
      )
      
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
    return
  end
  
  for i, mark in ipairs(marks) do
    local line_idx = i - 1
    local line_content = vim.api.nvim_buf_get_lines(popup_buf, line_idx, line_idx + 1, false)[1]
    
    if not line_content or #line_content == 0 then
      goto continue
    end
    
    -- Safe pattern-based highlighting
    local patterns = {
      -- Mark character (single letter at start of line)
      {
        pattern = "^([a-zA-Z])" .. config.separator,
        hl_group = mark.type == "global" and "MarkoGlobalMark" or "MarkoBufferMark",
        capture = 1  -- Highlight the captured group (the letter)
      },
      -- Line numbers (digits)
      {
        pattern = "(%d+)",
        hl_group = "MarkoLineNumber"
      }
    }
    
    -- Apply each pattern
    for _, p in ipairs(patterns) do
      local start_pos = 1
      while start_pos <= #line_content do
        local match_start, match_end, capture = line_content:find(p.pattern, start_pos)
        if not match_start then break end
        
        -- If we have a capture group, highlight just that
        if p.capture and capture then
          local capture_start = line_content:find(capture, match_start, true)
          if capture_start then
            vim.api.nvim_buf_set_extmark(popup_buf, ns_id, line_idx, capture_start - 1, {
              end_col = capture_start - 1 + #capture,
              hl_group = p.hl_group
            })
          end
        else
          -- Highlight the entire match
          vim.api.nvim_buf_set_extmark(popup_buf, ns_id, line_idx, match_start - 1, {
            end_col = match_end,
            hl_group = p.hl_group
          })
        end
        
        start_pos = match_end + 1
      end
    end
    
    -- Highlight filename section (between second and third separator)
    local separators = {}
    local start_pos = 1
    while true do
      local sep_pos = line_content:find(config.separator, start_pos)
      if not sep_pos then break end
      table.insert(separators, sep_pos)
      start_pos = sep_pos + 1
    end
    
    -- Filename is between 2nd and 3rd separator
    if #separators >= 3 then
      local filename_start = separators[2] + 1
      local filename_end = separators[3] - 1
      if filename_start <= filename_end then
        vim.api.nvim_buf_set_extmark(popup_buf, ns_id, line_idx, filename_start - 1, {
          end_col = filename_end,
          hl_group = "MarkoFilename"
        })
      end
    end
    
    ::continue::
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
  
  vim.keymap.set("n", "q", function()
    M.close_popup()
  end, { buffer = popup_buf, silent = true })
  
  -- Also close with the same key that opens it
  if config.default_keymap then
    vim.keymap.set("n", config.default_keymap, function()
      M.close_popup()
    end, { buffer = popup_buf, silent = true })
  end
  
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
