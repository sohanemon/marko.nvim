-- plugin/marko.lua
-- This file is automatically loaded by Neovim when the plugin is installed

-- Prevent loading twice
if vim.g.loaded_marko then
	return
end
vim.g.loaded_marko = true

-- Register the main command
vim.api.nvim_create_user_command("Marko", function()
	require("marko").show_marks()
end, {
	desc = "Show marks in a popup window",
})

-- Set up default keymap (configurable)
vim.defer_fn(function()
	local config = require("marko.config").get()

	-- Only set default keymap if it's not disabled
	if config.default_keymap and config.default_keymap ~= false then
		vim.keymap.set("n", config.default_keymap, function()
			require("marko").show_marks()
		end, { desc = "Show marks popup" })
	end
end, 100)

