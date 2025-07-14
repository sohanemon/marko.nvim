local M = {}

-- Namespace for virtual text marks
local ns_id = vim.api.nvim_create_namespace("marko_virtual_marks")

-- Track virtual marks to avoid duplicates
local virtual_marks = {}

-- Configuration for virtual text appearance
local default_config = {
  enabled = true,
  icon = "●",
  hl_group = "Comment",
  position = "eol",  -- "eol" or "overlay"
  format = function(mark, icon)
    return icon .. " " .. mark
  end
}

local config = default_config

-- Setup virtual text configuration
function M.setup(opts)
  config = vim.tbl_deep_extend("force", default_config, opts or {})
end

-- Get theme-aware highlight group for marks
local function get_mark_highlight(mark)
  -- Use the same highlight groups as the popup for consistency
  if mark:match("[a-z]") then
    return "MarkoBufferMark"  -- Blue for buffer marks
  else
    return "MarkoGlobalMark"  -- Red for global marks
  end
end

-- Show virtual text for a mark
function M.show_mark(bufnr, mark, line, col)
  if not config.enabled then
    return
  end
  
  -- Validate inputs
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  
  if not line or line <= 0 then
    return
  end
  
  -- Remove existing virtual mark for this mark in this buffer
  M.hide_mark(bufnr, mark)
  
  -- Create virtual text
  local virt_text = config.format(mark, config.icon)
  local mark_hl = get_mark_highlight(mark)
  
  -- Safely set extmark with error handling
  local success, extmark_id = pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line - 1, 0, {
    virt_text = {{virt_text, mark_hl}},
    virt_text_pos = config.position,
    priority = 100
  })
  
  if success and extmark_id then
    -- Track the virtual mark
    if not virtual_marks[bufnr] then
      virtual_marks[bufnr] = {}
    end
    virtual_marks[bufnr][mark] = extmark_id
  end
end

-- Hide virtual text for a mark
function M.hide_mark(bufnr, mark)
  if virtual_marks[bufnr] and virtual_marks[bufnr][mark] then
    vim.api.nvim_buf_del_extmark(bufnr, ns_id, virtual_marks[bufnr][mark])
    virtual_marks[bufnr][mark] = nil
  end
end

-- Hide all virtual marks in a buffer
function M.hide_all_marks(bufnr)
  if virtual_marks[bufnr] then
    for mark, extmark_id in pairs(virtual_marks[bufnr]) do
      vim.api.nvim_buf_del_extmark(bufnr, ns_id, extmark_id)
    end
    virtual_marks[bufnr] = {}
  end
end

-- Refresh virtual marks for current buffer
function M.refresh_buffer_marks(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  -- Validate buffer
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  
  -- Clear existing virtual marks
  M.hide_all_marks(bufnr)
  
  if not config.enabled then
    return
  end
  
  -- Get buffer marks directly from this buffer
  for i = string.byte('a'), string.byte('z') do
    local mark = string.char(i)
    local pos = vim.api.nvim_buf_get_mark(bufnr, mark)
    if pos[1] > 0 then
      M.show_mark(bufnr, mark, pos[1], pos[2])
    end
  end
  
  -- Get global marks - try the simplest approach
  for i = string.byte('A'), string.byte('Z') do
    local mark = string.char(i)
    -- For global marks, try to get them as if they were buffer marks
    -- If they return a valid position, they're in this buffer
    local success, pos = pcall(vim.api.nvim_buf_get_mark, bufnr, mark)
    if success and pos and pos[1] > 0 then
      M.show_mark(bufnr, mark, pos[1], pos[2])
    end
  end
end

-- Toggle virtual marks on/off
function M.toggle()
  config.enabled = not config.enabled
  
  if config.enabled then
    -- Refresh all buffers
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(bufnr) then
        M.refresh_buffer_marks(bufnr)
      end
    end
    vim.notify("Virtual marks enabled", vim.log.levels.INFO)
  else
    -- Hide all virtual marks
    for bufnr, _ in pairs(virtual_marks) do
      M.hide_all_marks(bufnr)
    end
    vim.notify("Virtual marks disabled", vim.log.levels.INFO)
  end
end

-- Hook into mark setting commands
function M.setup_mark_hooks()
  -- Override the 'm' command to trigger virtual text updates
  for i = string.byte('a'), string.byte('z') do
    local mark = string.char(i)
    vim.keymap.set('n', 'm' .. mark, function()
      -- Get the actual target buffer (not popup buffer if it's open)
      local bufnr = vim.api.nvim_get_current_buf()
      local popup = require("marko.popup")
      
      -- If popup is open, we need to get the previous buffer
      if popup.is_open() then
        -- Get the buffer that was active before the popup
        local all_bufs = vim.api.nvim_list_bufs()
        for _, buf in ipairs(all_bufs) do
          if vim.api.nvim_buf_is_loaded(buf) and 
             buf ~= bufnr and 
             vim.api.nvim_buf_get_option(buf, 'filetype') ~= 'marko-popup' and
             vim.api.nvim_buf_get_option(buf, 'buftype') == '' then
            bufnr = buf
            break
          end
        end
      end
      
      -- Set the mark normally FIRST
      vim.cmd('normal! m' .. mark)
      
      -- Then handle virtual text with a small delay to ensure mark is set
      vim.defer_fn(function()
        -- Hide existing virtual mark first
        M.hide_mark(bufnr, mark)
        
        -- Show new virtual text
        local pos = vim.api.nvim_buf_get_mark(bufnr, mark)
        if pos[1] > 0 then
          M.show_mark(bufnr, mark, pos[1], pos[2])
        end
      end, 1)  -- Very small delay
    end, { desc = 'Set mark ' .. mark .. ' with virtual text' })
  end
  
  -- For global marks (A-Z) - use a simpler approach
  for i = string.byte('A'), string.byte('Z') do
    local mark = string.char(i)
    vim.keymap.set('n', 'm' .. mark, function()
      -- Store the original buffer before anything else
      local popup = require("marko.popup")
      local target_bufnr = vim.api.nvim_get_current_buf()
      
      -- If popup is open, find the underlying buffer
      if popup.is_open() then
        -- Look for the most recently used normal buffer (not popup)
        local all_bufs = vim.api.nvim_list_bufs()
        for _, buf in ipairs(all_bufs) do
          if vim.api.nvim_buf_is_loaded(buf) and 
             buf ~= target_bufnr and 
             vim.api.nvim_buf_get_option(buf, 'filetype') ~= 'marko-popup' and
             vim.api.nvim_buf_get_option(buf, 'buftype') == '' then
            target_bufnr = buf
            break
          end
        end
      end
      
      -- Set the mark using the API directly instead of normal commands
      -- This works better from popup context
      local cursor_pos = vim.api.nvim_win_get_cursor(0)
      if popup.is_open() then
        -- When popup is open, we need to get cursor position from the target buffer window
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          if vim.api.nvim_win_get_buf(win) == target_bufnr then
            cursor_pos = vim.api.nvim_win_get_cursor(win)
            break
          end
        end
      end
      
      -- Set the mark directly using setpos
      vim.fn.setpos("'" .. mark, {target_bufnr, cursor_pos[1], cursor_pos[2] + 1, 0})
      
      -- Show virtual text immediately
      vim.defer_fn(function()
        if vim.api.nvim_buf_is_valid(target_bufnr) then
          -- Hide existing virtual mark first
          M.hide_mark(target_bufnr, mark)
          
          -- Show new virtual text
          M.show_mark(target_bufnr, mark, cursor_pos[1], cursor_pos[2])
        end
      end, 1)  -- Same short delay as buffer marks
    end, { desc = 'Set global mark ' .. mark .. ' with virtual text' })
  end
end

-- Setup autocommands to automatically show/hide marks
function M.setup_autocmds()
  local group = vim.api.nvim_create_augroup("MarkoVirtualMarks", { clear = true })
  
  -- Refresh marks when buffer is entered
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function(args)
      if args.buf and vim.api.nvim_buf_is_valid(args.buf) then
        vim.defer_fn(function()
          M.refresh_buffer_marks(args.buf)
        end, 50)
      end
    end
  })
  
  -- Clean up when buffer is deleted
  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    callback = function(args)
      if virtual_marks[args.buf] then
        virtual_marks[args.buf] = nil
      end
    end
  })
  
  -- Setup mark setting hooks
  M.setup_mark_hooks()
end

return M