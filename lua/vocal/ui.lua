-- File: lua/vocal/ui.lua
local M = {}

-- Status window state
local status_win = nil
local status_buf = nil
local status_timer = nil
local default_width = 30

function M.create_status_window()
	if status_win and vim.api.nvim_win_is_valid(status_win) then
		vim.api.nvim_win_close(status_win, true)
	end
	status_win = nil
	status_buf = nil
	status_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(status_buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(status_buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(status_buf, "swapfile", false)
	vim.api.nvim_buf_set_option(status_buf, "filetype", "vocal-status")
	local width = default_width
	local height = 1
	local row = math.max(0, vim.o.lines - height - 4)
	local col = math.max(0, vim.o.columns - width - 2)
	status_win = vim.api.nvim_open_win(status_buf, false, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "none",
		focusable = false,
	})
	if not status_win or not vim.api.nvim_win_is_valid(status_win) then
		return false
	end
	vim.api.nvim_win_set_option(status_win, "winblend", 0)
	vim.api.nvim_win_set_option(status_win, "winhighlight", "Normal:VocalStatus,FloatBorder:VocalStatusBorder")
	if vim.fn.hlexists("VocalStatus") == 0 then
		vim.api.nvim_set_hl(0, "VocalStatus", { bg = "#2a2a2a", fg = "#ffffff" })
	end
	if vim.fn.hlexists("VocalStatusBorder") == 0 then
		vim.api.nvim_set_hl(0, "VocalStatusBorder", { bg = "#2a2a2a", fg = "#2a2a2a" })
	end
	vim.api.nvim_buf_set_lines(status_buf, 0, -1, false, { "📡 Initializing..." })
	return true
end

function M.update_status(text, auto_close_delay)
	vim.schedule(function()
		if not status_win or not vim.api.nvim_win_is_valid(status_win) then
			local success = M.create_status_window()
			if not success then
				vim.notify(text, vim.log.levels.INFO)
				return
			end
		end
		local width = default_width
		if status_win and vim.api.nvim_win_is_valid(status_win) then
			width = vim.api.nvim_win_get_width(status_win)
		end
		local clean_text = text:gsub("\n", " "):gsub("\r", " ")
		local first_line = clean_text:match("^[^\n]*") or clean_text
		local padding = math.floor((width - vim.fn.strwidth(first_line)) / 2)
		local padded_text = string.rep(" ", math.max(0, padding)) .. first_line
		if status_buf and vim.api.nvim_buf_is_valid(status_buf) then
			vim.api.nvim_buf_set_lines(status_buf, 0, -1, false, { padded_text })
		end
		if status_timer then
			vim.fn.timer_stop(status_timer)
			status_timer = nil
		end
		if auto_close_delay and auto_close_delay > 0 then
			status_timer = vim.fn.timer_start(auto_close_delay, function()
				M.close_status_window()
			end)
		end
	end)
end

function M.close_status_window()
	vim.schedule(function()
		if status_timer then
			vim.fn.timer_stop(status_timer)
			status_timer = nil
		end
		if status_win and vim.api.nvim_win_is_valid(status_win) then
			vim.api.nvim_win_close(status_win, true)
		end
		status_win = nil
		status_buf = nil
	end)
end

function M.show_spinner(message, spinner_frames)
	local spinner_idx = 1
	local function animate()
		vim.schedule(function()
			if status_win and vim.api.nvim_win_is_valid(status_win) then
				local frame = spinner_frames[spinner_idx] or ""
				local text = frame .. " " .. message
				M.update_status(text)
				spinner_idx = (spinner_idx % #spinner_frames) + 1
			end
		end)
	end
	local timer_id
	timer_id = vim.fn.timer_start(100, function()
		animate()
	end, { ["repeat"] = -1 })
	return timer_id
end

function M.show_debug_status()
	M.update_status("🔍 Status window visible", 5000)
end

return M
