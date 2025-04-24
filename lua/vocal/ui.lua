local M = {}

local status_win_id = nil
local status_bufnr = nil
local spinner_timer = nil
local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local current_frame = 1

local function close_window()
	if spinner_timer then
		vim.loop.timer_stop(spinner_timer)
		spinner_timer = nil
	end
	if status_win_id and vim.api.nvim_win_is_valid(status_win_id) then
		vim.api.nvim_win_close(status_win_id, true)
	end
	status_win_id = nil
	status_bufnr = nil
end

local function create_or_update_window(text)
	if not status_bufnr or not vim.api.nvim_buf_is_valid(status_bufnr) then
		status_bufnr = vim.api.nvim_create_buf(false, true)
	end
	vim.api.nvim_buf_set_lines(status_bufnr, 0, -1, false, { text })
	if not status_win_id or not vim.api.nvim_win_is_valid(status_win_id) then
		local win_config = {
			relative = "editor",
			width = 30,
			height = 1,
			row = vim.o.lines - 2,
			col = vim.o.columns - 32,
			style = "minimal",
			border = "none",
		}
		status_win_id = vim.api.nvim_open_win(status_bufnr, false, win_config)
	else
		vim.api.nvim_win_set_buf(status_win_id, status_bufnr)
	end
end

function M.show_recording_status()
	create_or_update_window("󰑊 Recording")
end

function M.start_transcribing_status()
	current_frame = 1
	create_or_update_window(spinner_frames[current_frame] .. " Transcribing")
	spinner_timer = vim.loop.new_timer()
	spinner_timer:start(
		100,
		100,
		vim.schedule_wrap(function()
			current_frame = (current_frame % #spinner_frames) + 1
			create_or_update_window(spinner_frames[current_frame] .. " Transcribing")
		end)
	)
end

function M.show_error_status(message)
	close_window()
	create_or_update_window("✗ " .. message)
	vim.defer_fn(function()
		M.hide_status()
	end, 3000)
end

function M.show_success_status(message)
	close_window()
	create_or_update_window("✓ " .. message)
	vim.defer_fn(function()
		M.hide_status()
	end, 2000)
end

function M.hide_status()
	close_window()
end

return M
