local M = {}

-- Get all marks in the current buffer
function M.get_buffer_marks()
	local marks = {}
	local buf = vim.api.nvim_get_current_buf()

	-- Get lowercase marks (buffer-local)
	for i = string.byte("a"), string.byte("z") do
		local mark = string.char(i)
		local pos = vim.api.nvim_buf_get_mark(buf, mark)
		if pos[1] > 0 then
			local line = vim.api.nvim_buf_get_lines(buf, pos[1] - 1, pos[1], false)[1] or ""
			table.insert(marks, {
				mark = mark,
				line = pos[1],
				col = pos[2],
				text = line:sub(1, 50), -- Truncate long lines
				type = "buffer",
			})
		end
	end

	return marks
end

-- Get buffer marks from all loaded buffers
function M.get_all_buffer_marks()
	local marks = {}
	
	-- Get all loaded buffers
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) then
			local filename = vim.api.nvim_buf_get_name(buf)
			
			-- Get lowercase marks (buffer-local) from this buffer
			for i = string.byte("a"), string.byte("z") do
				local mark = string.char(i)
				local pos = vim.api.nvim_buf_get_mark(buf, mark)
				if pos[1] > 0 then
					local line = vim.api.nvim_buf_get_lines(buf, pos[1] - 1, pos[1], false)[1] or ""
					table.insert(marks, {
						mark = mark,
						line = pos[1],
						col = pos[2],
						text = line:sub(1, 50),
						filename = filename,
						type = "buffer",
					})
				end
			end
		end
	end

	return marks
end

-- Get all global marks
function M.get_global_marks()
	local marks = {}
	local config = require("marko.config").get()

	-- Get uppercase marks (global)
	for i = string.byte("A"), string.byte("Z") do
		local mark = string.char(i)
		local pos = vim.api.nvim_get_mark(mark, {})
		if pos[1] > 0 then
			local filename = ""
			local line_text = ""
			
			-- Try multiple methods to get the filename
			-- Method 1: Check getmarklist
			local mark_list = vim.fn.getmarklist()
			for _, mark_entry in ipairs(mark_list) do
				if mark_entry.mark == "'" .. mark and mark_entry.file then
					filename = mark_entry.file
					break
				end
			end
			
			-- Method 2: Parse marks command output
			if filename == "" then
				local marks_output = vim.fn.execute("marks " .. mark)
				for line in marks_output:gmatch("[^\r\n]+") do
					if line:match("^%s*" .. mark .. "%s") then
						-- Try to extract filename - look for anything after the numbers
						local filepath = line:match("^%s*" .. mark .. "%s+%d+%s+%d+%s+(.+)$")
						if filepath and filepath ~= "" and filepath ~= "-" then
							filename = filepath
							break
						end
					end
				end
			end
			
			-- Method 3: If mark is in current buffer, use current buffer name
			if filename == "" then
				local current_buf = vim.api.nvim_get_current_buf()
				local current_marks = vim.api.nvim_buf_get_marks(current_buf, mark, mark, {})
				if #current_marks > 0 then
					filename = vim.api.nvim_buf_get_name(current_buf)
				end
			end
			
			-- Method 4: Last resort - check all loaded buffers for this mark
			if filename == "" then
				for _, buf in ipairs(vim.api.nvim_list_bufs()) do
					if vim.api.nvim_buf_is_loaded(buf) then
						local buf_marks = vim.api.nvim_buf_get_marks(buf, mark, mark, {})
						if #buf_marks > 0 and buf_marks[1][1] == pos[1] then
							filename = vim.api.nvim_buf_get_name(buf)
							break
						end
					end
				end
			end
			
			-- Try to get line text with multiple methods
			-- Method 1: If mark is in current buffer, get text directly
			local current_buf = vim.api.nvim_get_current_buf()
			if filename == vim.api.nvim_buf_get_name(current_buf) then
				local lines = vim.api.nvim_buf_get_lines(current_buf, pos[1] - 1, pos[1], false)
				if lines and lines[1] then
					line_text = lines[1]
				end
			else
				-- Method 2: Check if the file is loaded in a buffer
				local loaded_buf = nil
				for _, buf in ipairs(vim.api.nvim_list_bufs()) do
					if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_name(buf) == filename then
						loaded_buf = buf
						break
					end
				end
				
				if loaded_buf then
					-- Get line from loaded buffer
					local lines = vim.api.nvim_buf_get_lines(loaded_buf, pos[1] - 1, pos[1], false)
					if lines and lines[1] then
						line_text = lines[1]
					end
				elseif filename ~= "" and vim.fn.filereadable(filename) == 1 then
					-- Method 3: Read from file (last resort)
					local lines = vim.fn.readfile(filename, "", pos[1])
					if lines and #lines >= pos[1] then
						line_text = lines[pos[1]]
					end
				end
			end
			
			-- Fallback: if still no text, try to get it from the mark position directly
			if line_text == "" then
				-- Try using vim's built-in getline at the mark position
				local success, result = pcall(function()
					vim.cmd("normal! '" .. mark)
					return vim.fn.getline(".")
				end)
				if success and result then
					line_text = result
					-- Return to original position
					vim.cmd("normal! ''")
				end
			end

			table.insert(marks, {
				mark = mark,
				line = pos[1],
				col = pos[2],
				text = line_text:sub(1, 50),
				filename = filename,
				type = "global",
			})
		end
	end

	return marks
end


-- Deduplicate marks at the same location, prioritizing buffer marks over global marks
function M.deduplicate_marks(marks)
	local seen = {}
	local deduplicated = {}
	
	-- Define priority: buffer > global
	local priority = { buffer = 1, global = 2 }
	
	for _, mark in ipairs(marks) do
		local key = (mark.filename or "") .. ":" .. mark.line .. ":" .. mark.col
		
		if not seen[key] then
			-- First mark at this location
			seen[key] = mark
			table.insert(deduplicated, mark)
		else
			-- Duplicate location - keep the higher priority mark
			local existing = seen[key]
			if priority[mark.type] < priority[existing.type] then
				-- Replace with higher priority mark
				seen[key] = mark
				-- Replace in deduplicated array
				for i, existing_mark in ipairs(deduplicated) do
					if existing_mark == existing then
						deduplicated[i] = mark
						break
					end
				end
			end
		end
	end
	
	return deduplicated
end

-- Debug function to check what vim thinks about marks
function M.debug_marks()
	print("=== Debug Mark Information ===")
	print("Shada setting:", vim.o.shada)
	print("Current buffer:", vim.api.nvim_buf_get_name(0))
	
	-- Test what vim's :marks command shows
	local marks_output = vim.fn.execute("marks")
	print("Vim marks output:")
	print(marks_output)
	
	print("=== End Debug ===")
end

-- Get all marks (buffer and global)
function M.get_all_marks()
	local all_marks = {}
	local config = require("marko.config").get()
	
	-- Get buffer marks - either from current buffer or all buffers based on config
	local buffer_marks = config.show_all_buffers and M.get_all_buffer_marks() or M.get_buffer_marks()
	local global_marks = M.get_global_marks()

	-- Combine all marks
	for _, mark in ipairs(buffer_marks) do
		table.insert(all_marks, mark)
	end

	for _, mark in ipairs(global_marks) do
		table.insert(all_marks, mark)
	end

	-- Deduplicate marks at the same location
	all_marks = M.deduplicate_marks(all_marks)

	-- Sort by mark name
	table.sort(all_marks, function(a, b)
		return a.mark < b.mark
	end)

	return all_marks
end

-- Delete a mark
function M.delete_mark(mark_info)
	local mark = mark_info.mark
	
	if mark_info.type == "buffer" and mark_info.filename then
		-- For buffer marks, we need to delete from the specific buffer
		local buffers = vim.api.nvim_list_bufs()
		for _, buf in ipairs(buffers) do
			if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_name(buf) == mark_info.filename then
				-- Use vim.cmd with buffer-specific syntax instead of switching buffers
				vim.cmd(buf .. "bufdo delmarks " .. mark)
				break
			end
		end
	else
		-- For global marks, delete normally
		vim.cmd("delmarks " .. mark)
	end
end

-- Go to a mark
function M.goto_mark(mark_info)
	-- For global marks, use vim's native mark jumping which handles file switching
	if mark_info.type == "global" then
		vim.cmd("normal! '" .. mark_info.mark)
		return
	end
	
	-- For buffer marks, switch to the correct file if needed
	if mark_info.filename and mark_info.filename ~= "" then
		local current_file = vim.api.nvim_buf_get_name(0)
		-- Only switch files if we're not already in the target file
		if current_file ~= mark_info.filename then
			-- Check if file exists before trying to open it
			if vim.fn.filereadable(mark_info.filename) == 1 then
				vim.cmd("edit " .. vim.fn.fnameescape(mark_info.filename))
			else
				vim.notify("File not found: " .. mark_info.filename, vim.log.levels.ERROR)
				return
			end
		end
	end
	
	-- Validate cursor position before setting
	local line_count = vim.api.nvim_buf_line_count(0)
	local target_line = math.max(1, math.min(mark_info.line, line_count))
	
	-- Get the actual line to validate column
	local lines = vim.api.nvim_buf_get_lines(0, target_line - 1, target_line, false)
	local line_length = lines[1] and #lines[1] or 0
	local target_col = math.max(0, math.min(mark_info.col, line_length))
	
	vim.api.nvim_win_set_cursor(0, { target_line, target_col })
end

return M
