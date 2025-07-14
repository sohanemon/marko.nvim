local M = {}

local default_config = {
  width = 100,
  height = 50,
  border = "rounded",
  title = " Marks ",
  -- Default keymap to open popup (set to false to disable)
  default_keymap = '<S-">',
  keymaps = {
    delete = "d",
    goto = "<CR>",
    close = "<Esc>",
  },
  exclude_marks = { "'", "`", "^", ".", "[", "]", "<", ">" },
  -- Show buffer marks from all buffers or just current buffer
  show_all_buffers = true,
}

local config = default_config

function M.setup(opts)
  config = vim.tbl_deep_extend("force", default_config, opts or {})
end

function M.get()
  return config
end

return M
