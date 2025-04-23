-- File: lua/vocal/ui.lua
local M = {}

-- Status window state
local status_win = nil
local status_buf = nil
local status_timer = nil
local default_width = 30

-- Create a floating status window at the bottom right
function M.create_status_window()
	-- Close existing window if any
	if status_win and vim.api.nvim_win_is_valid(status_win) then
		vim.api.nvim_win_close(status_win, true)
	end

	-- Reset window and buffer
	status_win = nil
	status_buf = nil

	-- Create buffer if needed
	status_buf = vim.api.nvim_create_buf(false, true)

	-- Set buffer options
	vim.api.nvim_buf_set_option(status_buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(status_buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(status_buf, "swapfile", false)
	vim.api.nvim_buf_set_option(status_buf, "filetype", "vocal-status")

	-- Calculate position (bottom right)
	local width = default_width
	local height = 1
	-- Ensure we're within screen bounds
	local row = math.max(0, vim.o.lines - height - 4)
	local col = math.max(0, vim.o.columns - width - 2)

	-- Create window with no border but ensure it's visible
	status_win = vim.api.nvim_open_win(status_buf, false, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "single",
		focusable = false,
	})

	-- Check if window was created successfully
	if not status_win or not vim.api.nvim_win_is_valid(status_win) then
		return false
	end

	-- Make window visible with proper highlighting
	vim.api.nvim_win_set_option(status_win, "winblend", 0) -- Remove transparency
	vim.api.nvim_win_set_option(status_win, "winhighlight", "Normal:VocalStatus,FloatBorder:VocalStatusBorder")

	-- Add default highlighting if not already defined
	if vim.fn.hlexists("VocalStatus") == 0 then
		vim.api.nvim_set_hl(0, "VocalStatus", { bg = "#2a2a2a", fg = "#ffffff" })
	end

	if vim.fn.hlexists("VocalStatusBorder") == 0 then
		vim.api.nvim_set_hl(0, "VocalStatusBorder", { bg = "#2a2a2a", fg = "#2a2a2a" })
	end

	-- Set initial content to make sure something is visible
	vim.api.nvim_buf_set_lines(status_buf, 0, -1, false, { "📡 Initializing..." })

	return true
end

-- Update status window content
function M.update_status(text, auto_close_delay)
	-- Wrap the entire function in vim.schedule to ensure it runs in the main event loop
	vim.schedule(function()
		if not status_win or not vim.api.nvim_win_is_valid(status_win) then
			local success = M.create_status_window()
			if not success then
				-- Fallback to simple notification if window creation fails
				vim.notify(text, vim.log.levels.INFO)
				return
			end
		end

		-- Get window width with error checking
		local width = default_width
		if status_win and vim.api.nvim_win_is_valid(status_win) then
			width = vim.api.nvim_win_get_width(status_win)
		end

		-- Sanitize text: remove newlines and get first line only
		local clean_text = text:gsub("\n", " ")
		clean_text = clean_text:gsub("\r", " ")

		-- Extract first line if text contains multiple lines
		local first_line = clean_text:match("^[^\n]*") or clean_text

		-- Center the text in the window
		local padding = math.floor((width - vim.fn.strwidth(first_line)) / 2)
		local padded_text = string.rep(" ", math.max(0, padding)) .. first_line

		-- Update buffer content
		if status_buf and vim.api.nvim_buf_is_valid(status_buf) then
			vim.api.nvim_buf_set_lines(status_buf, 0, -1, false, { padded_text })
		end

		-- Cancel existing timer if any
		if status_timer then
			vim.fn.timer_stop(status_timer)
			status_timer = nil
		end

		-- Set auto-close timer if delay specified
		if auto_close_delay and auto_close_delay > 0 then
			status_timer = vim.fn.timer_start(auto_close_delay, function()
				M.close_status_window()
			end)
		end
	end)
end

-- Close status window
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

-- Show spinner animation in status window
function M.show_spinner(message, spinner_frames)
	local spinner_idx = 1

	-- Start spinner animation
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

	-- Start animation loop
	local timer_id
	timer_id = vim.fn.timer_start(100, function()
		animate()
	end, { ["repeat"] = -1 })

	return timer_id
end

-- Add a debug command to manually show the status window
function M.show_debug_status()
	M.update_status("🔍 Status window visible", 5000)
end

-- Create a popup window for recording status
function M.create_recording_popup(on_stop, on_cancel)
	local buf = vim.api.nvim_create_buf(false, true) -- Scratch buffer
	local width, height = 40, 5
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	-- Create the popup window
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "single",
		title = "Vocal Recording",
		title_pos = "center",
	})

	-- Set initial content
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
		"",
		"   Recording...",
		"  Press <Enter> to stop and save",
		"  Press <Esc> to cancel",
		"",
	})

	-- Keymaps for stopping and canceling
	vim.keymap.set({ "n", "i" }, "<Enter>", function()
		on_stop()
		vim.api.nvim_win_close(win, true)
		vim.api.nvim_buf_delete(buf, { force = true })
	end, { buffer = buf, silent = true })

	vim.keymap.set({ "n", "i" }, "<Esc>", function()
		on_cancel()
		vim.api.nvim_win_close(win, true)
		vim.api.nvim_buf_delete(buf, { force = true })
	end, { buffer = buf, silent = true })

	return buf, win
end

return M

