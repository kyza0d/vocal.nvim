local M = {}

-- Insert text at cursor position in normal mode
---@param text string Text to insert
function M.insert_at_cursor(text)
	-- Get current cursor position
	local line, col = unpack(vim.api.nvim_win_get_cursor(0))

	-- Get current line content
	local current_line = vim.api.nvim_get_current_line()

	-- Split the line at cursor position
	local line_start = string.sub(current_line, 1, col)
	local line_end = string.sub(current_line, col + 1)

	-- Insert text between split parts
	local new_line = line_start .. text .. line_end

	-- Update the line
	vim.api.nvim_set_current_line(new_line)

	-- Update cursor position after insertion
	local new_col = col + #text
	vim.api.nvim_win_set_cursor(0, { line, new_col })
end

-- Replace selected text in visual mode
---@param text string Text to replace selection with
function M.replace_visual_selection(text)
	-- Get the current mode
	local mode = vim.api.nvim_get_mode().mode

	-- Check if we were previously in visual mode
	local was_visual = vim.fn.mode(1):match("[vV]")

	if not was_visual then
		return false
	end

	-- Get start and end positions of selection
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")

	-- Convert to 0-indexed
	local start_line = start_pos[2] - 1
	local start_col = start_pos[3] - 1
	local end_line = end_pos[2] - 1
	local end_col = end_pos[3]

	-- Handle visual line mode
	if vim.fn.visualmode() == "V" then
		start_col = 0
		-- Get end line content length
		local end_line_content = vim.api.nvim_buf_get_lines(0, end_line, end_line + 1, false)[1] or ""
		end_col = #end_line_content
	end

	-- Replace selection with text
	vim.api.nvim_buf_set_text(0, start_line, start_col, end_line, end_col, { text })

	return true
end

-- Insert text at cursor or replace visual selection
---@param text string Text to insert
function M.insert_text(text)
	-- Check if we're in visual mode and try to replace selection
	if not M.replace_visual_selection(text) then
		-- If not in visual mode or replacement failed, insert at cursor
		M.insert_at_cursor(text)
	end
end

return M