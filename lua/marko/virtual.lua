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
      local bufnr = vim.api.nvim_get_current_buf()
      
      -- Hide existing virtual mark first (in case we're moving it)
      M.hide_mark(bufnr, mark)
      
      -- Set the mark normally
      vim.cmd('normal! m' .. mark)
      
      -- Show virtual text immediately
      vim.defer_fn(function()
        local pos = vim.api.nvim_buf_get_mark(bufnr, mark)
        if pos[1] > 0 then
          M.show_mark(bufnr, mark, pos[1], pos[2])
        end
      end, 10)
    end, { desc = 'Set mark ' .. mark .. ' with virtual text' })
  end
  
  -- Same for global marks (A-Z)
  for i = string.byte('A'), string.byte('Z') do
    local mark = string.char(i)
    vim.keymap.set('n', 'm' .. mark, function()
      local bufnr = vim.api.nvim_get_current_buf()
      
      -- Hide any existing virtual mark for this global mark in all buffers
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
          M.hide_mark(buf, mark)
        end
      end
      
      -- Set the mark normally first
      vim.cmd('normal! m' .. mark)
      
      -- Show virtual text immediately in current buffer
      vim.defer_fn(function()
        if vim.api.nvim_buf_is_valid(bufnr) then
          -- Use the same approach as buffer marks
          local pos = vim.api.nvim_buf_get_mark(bufnr, mark)
          if pos[1] > 0 then
            M.show_mark(bufnr, mark, pos[1], pos[2])
          end
        end
      end, 10)
    end, { desc = 'Set global mark ' .. mark .. ' with virtual text' })
  end
  
  -- Hook into delmarks command
  vim.api.nvim_create_user_command('Delmarks', function(opts)
    local args = opts.args
    
    -- Execute the original delmarks command
    vim.cmd('delmarks ' .. args)
    
    -- Remove virtual text for deleted marks
    local bufnr = vim.api.nvim_get_current_buf()
    
    -- Parse which marks were deleted
    for mark in args:gmatch('[a-zA-Z]') do
      if mark:match('[a-z]') then
        -- Buffer mark
        M.hide_mark(bufnr, mark)
      else
        -- Global mark - remove from all buffers
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_is_loaded(buf) then
            M.hide_mark(buf, mark)
          end
        end
      end
    end
  end, { nargs = '+', complete = 'command' })
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