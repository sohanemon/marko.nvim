-- plugin/marko.lua
-- This file is automatically loaded by Neovim when the plugin is installed

-- Prevent loading twice
if vim.g.loaded_marko then
  return
end
vim.g.loaded_marko = true

-- Register the main command
vim.api.nvim_create_user_command('Marko', function()
  require('marko').show_marks()
end, {
  desc = 'Show marks in a popup window'
})

-- Optional: Create a keymap that users can override
-- This is just a default, users can remap in their config
vim.keymap.set('n', '<leader>m', function()
  require('marko').show_marks()
end, { desc = 'Show marks popup' })