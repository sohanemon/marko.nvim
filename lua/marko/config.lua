local M = {}

local default_config = {
  width = 100,
  height = 100,
  border = "rounded",
  title = " Marks ",
  -- Default keymap to open popup (set to false to disable)
  default_keymap = "'",
  keymaps = {
    delete = "d",
    goto = "<CR>",
    close = "<Esc>",
  },
  exclude_marks = { "'", "`", "^", ".", "[", "]", "<", ">" },
  -- Show buffer marks from all buffers or just current buffer
  show_all_buffers = true,
  
  -- Visual styling options
  transparency = 0,  -- 0-100, window background transparency
  shadow = false,    -- Drop shadow effect
  
  -- Separator character
  separator = "│",   -- Column separator
  
  -- Column widths for better alignment
  columns = {
    icon = 3,
    mark = 4,
    line = 6,
    filename = 25,
    separator = 2
  },
  
  -- Custom highlight groups (users can override these)
  highlights = {
    -- Window highlights
    normal = { link = "Normal" },
    border = { link = "FloatBorder" },
    title = { link = "Title" },
    cursor_line = { bg = "#3E4451" },
    
    -- Content highlights
    buffer_mark = { fg = "#61AFEF", bold = true },  -- Blue for buffer marks
    global_mark = { fg = "#E06C75", bold = true },  -- Red for global marks
    line_number = { fg = "#ABB2BF" },               -- Gray for line numbers
    filename = { fg = "#98C379", italic = true },   -- Green for filenames
    content = { fg = "#ABB2BF" },                   -- Gray for content
    separator = { fg = "#5C6370" }                  -- Dark gray for separators
  }
}

local config = default_config

-- Setup highlight groups
local function setup_highlights()
  local highlights = config.highlights
  
  -- Define all custom highlight groups
  local hl_groups = {
    MarkoNormal = highlights.normal,
    MarkoBorder = highlights.border,
    MarkoTitle = highlights.title,
    MarkoCursorLine = highlights.cursor_line,
    MarkoBufferMark = highlights.buffer_mark,
    MarkoGlobalMark = highlights.global_mark,
    MarkoLineNumber = highlights.line_number,
    MarkoFilename = highlights.filename,
    MarkoContent = highlights.content,
    MarkoSeparator = highlights.separator
  }
  
  -- Apply highlight groups
  for group, opts in pairs(hl_groups) do
    vim.api.nvim_set_hl(0, group, opts)
  end
end

-- Create namespace for extmarks
local ns_id = vim.api.nvim_create_namespace("marko_highlights")

function M.setup(opts)
  config = vim.tbl_deep_extend("force", default_config, opts or {})
  
  -- Setup highlights after config is merged
  setup_highlights()
end

function M.get()
  return config
end

function M.get_namespace()
  return ns_id
end

-- Function to refresh highlights (useful for theme changes)
function M.refresh_highlights()
  setup_highlights()
end

return M
