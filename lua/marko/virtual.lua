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

-- Show virtual text for a mark
function M.show_mark(bufnr, mark, line, col)
  if not config.enabled then
    return
  end
  
  -- Remove existing virtual mark for this mark in this buffer
  M.hide_mark(bufnr, mark)
  
  -- Create virtual text
  local virt_text = config.format(mark, config.icon)
  local mark_hl = mark:match("[a-z]") and "DiagnosticInfo" or "DiagnosticWarn"
  
  local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, line - 1, 0, {
    virt_text = {{virt_text, mark_hl}},
    virt_text_pos = config.position,
    priority = 100
  })
  
  -- Track the virtual mark
  if not virtual_marks[bufnr] then
    virtual_marks[bufnr] = {}
  end
  virtual_marks[bufnr][mark] = extmark_id
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
  
  -- Clear existing virtual marks
  M.hide_all_marks(bufnr)
  
  if not config.enabled then
    return
  end
  
  -- Get all marks in this buffer
  local marks_module = require("marko.marks")
  local buffer_marks = marks_module.get_buffer_marks()
  
  -- Show virtual text for each mark
  for _, mark_info in ipairs(buffer_marks) do
    M.show_mark(bufnr, mark_info.mark, mark_info.line, mark_info.col)
  end
  
  -- Also check for global marks in this buffer
  local global_marks = marks_module.get_global_marks()
  for _, mark_info in ipairs(global_marks) do
    local current_file = vim.api.nvim_buf_get_name(bufnr)
    if mark_info.filename == current_file then
      M.show_mark(bufnr, mark_info.mark, mark_info.line, mark_info.col)
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

-- Setup autocommands to automatically show/hide marks
function M.setup_autocmds()
  local group = vim.api.nvim_create_augroup("MarkoVirtualMarks", { clear = true })
  
  -- Refresh marks when buffer is entered
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function()
      vim.defer_fn(function()
        M.refresh_buffer_marks()
      end, 100)  -- Small delay to ensure marks are loaded
    end
  })
  
  -- Refresh marks when text changes (marks might be added/removed)
  vim.api.nvim_create_autocmd("TextChanged", {
    group = group,
    callback = function()
      vim.defer_fn(function()
        M.refresh_buffer_marks()
      end, 200)
    end
  })
  
  -- Clean up when buffer is deleted
  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    callback = function(args)
      virtual_marks[args.buf] = nil
    end
  })
end

return M