local M = {}

-- Insert text at cursor position in normal mode
---@param text string Text to insert
function M.insert_at_cursor(text)
	local line, col = unpack(vim.api.nvim_win_get_cursor(0))
	local current_line = vim.api.nvim_get_current_line()
	local line_start = string.sub(current_line, 1, col)
	local line_end = string.sub(current_line, col + 1)
	local new_line = line_start .. text .. line_end
	vim.api.nvim_set_current_line(new_line)
	local new_col = col + #text
	vim.api.nvim_win_set_cursor(0, { line, new_col })
end

-- Insert text at cursor
---@param text string Text to insert
function M.insert_text(text)
	M.insert_at_cursor(text)
end

return M
