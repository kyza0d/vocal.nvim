-- File: lua/vocal/init.lua
local M = {}
local recording = require("vocal.recording")
local ui = require("vocal.ui")
local api = require("vocal.api")
local buffer = require("vocal.buffer")

M.config = require("vocal.config")

local resolved_api_key = nil
local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local spinner_timer = nil

local function show_status(message, auto_close_delay)
	ui.update_status(message, auto_close_delay)
end

local function show_error(message)
	ui.update_status("❌ " .. message, 5000)
end

local function show_info(message, auto_close_delay)
	ui.update_status("📢 " .. message, auto_close_delay or 3000)
end

local function resolve_api_key()
	if resolved_api_key then
		return resolved_api_key
	end
	local key = M.config.api_key
	if key == nil then
		local env_key = os.getenv("OPENAI_API_KEY")
		if env_key and env_key:match("^%s*(.-)%s*$") ~= "" then
			resolved_api_key = env_key:match("^%s*(.-)%s*$")
		end
	elseif type(key) == "string" then
		resolved_api_key = key:match("^%s*(.-)%s*$")
	elseif type(key) == "table" then
		local cmd = key[1]
		local args = { unpack(key, 2) }
		local output = vim.fn.systemlist({ cmd, unpack(args) })
		if vim.v.shell_error == 0 and #output > 0 then
			resolved_api_key = output[1]:gsub("^%s*(.-)%s*$", "%1")
		else
			resolved_api_key = nil
		end
	else
		resolved_api_key = nil
	end
	if resolved_api_key then
		if not resolved_api_key:match("^sk%-") then
			show_error("API key doesn't have expected format")
		end
		if #resolved_api_key < 30 then
			show_error("API key looks too short")
		end
	end
	return resolved_api_key
end

local function start_spinner(message)
	if spinner_timer then
		pcall(function()
			vim.fn.timer_stop(spinner_timer)
		end)
		spinner_timer = nil
	end
	spinner_timer = ui.show_spinner(message, spinner_frames)
end

local function stop_spinner()
	if spinner_timer then
		pcall(function()
			vim.fn.timer_stop(spinner_timer)
		end)
		spinner_timer = nil
	end
end

local function delete_recording_file(filename)
	if vim.fn.filereadable(filename) ~= 1 then
		return false
	end
	local success, error_msg = os.remove(filename)
	if not success then
		if api.debug_mode then
			local debug_log = function(msg)
				local file = io.open(api.log_file, "a")
				if file then
					file:write("[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] " .. msg .. "\n")
					file:close()
				end
			end
			debug_log("Failed to delete recording file: " .. (error_msg or "unknown error"))
		end
		return false
	end
	return true
end

local function process_recording(filename)
	local api_key = resolve_api_key()
	if not api_key then
		show_error("OpenAI API key not found")
		return
	end
	start_spinner("Transcribing audio...")
	api.transcribe(filename, api_key, function(text)
		stop_spinner()
		text = text:gsub("^%s+", ""):gsub("%s+$", ""):gsub("\r\n", "\n")
		buffer.insert_at_cursor(text)
		if M.config.delete_recordings then
			if delete_recording_file(filename) then
				show_status("🎙️ Transcription complete (recording deleted)", 3000)
			else
				show_status("🎙️ Transcription complete", 3000)
			end
		else
			show_status("🎙️ Transcription complete", 3000)
		end
	end, function(error_msg)
		stop_spinner()
		show_error("Transcription failed: " .. error_msg)
		if error_msg:match("API error") then
			vim.defer_fn(function()
				show_info("Enable debug mode with :VocalDebug")
			end, 1000)
		end
	end)
end

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
	if opts and opts.api then
		api.set_options(opts.api)
	end
	vim.api.nvim_create_user_command("Vocal", M.transcribe, {
		range = true,
		desc = "Start or stop audio recording and transcribe using OpenAI Whisper API",
	})
	vim.api.nvim_create_user_command("VocalDebug", function()
		api.enable_debug()
	end, {
		desc = "Enable debug mode for Vocal plugin",
	})
	vim.api.nvim_create_user_command("VocalNoDebug", function()
		api.disable_debug()
	end, {
		desc = "Disable debug mode for Vocal plugin",
	})
	vim.api.nvim_create_user_command("VocalOpenLog", function()
		if vim.fn.filereadable(api.log_file) == 1 then
			vim.cmd("edit " .. api.log_file)
		else
			show_error("Log file does not exist yet")
		end
	end, {
		desc = "Open the Vocal debug log file",
	})
	if M.config.keymap then
		vim.keymap.set("n", M.config.keymap, ":Vocal<CR>", {
			desc = "Start/stop Vocal recording",
			silent = true,
		})
	end
end

function M.transcribe(cmd_opts)
	local api_key = resolve_api_key()
	if not api_key then
		show_error("OpenAI API key not found")
		return
	end
	if recording.is_recording() then
		local filename = recording.get_recording_filename()
		show_status("🛑 Stopping recording...")
		recording.stop_recording()
		vim.defer_fn(function()
			show_status("📦 Processing recording...", 2000)
			process_recording(filename)
		end, 1000)
		return
	end
	recording.start_recording(M.config.recording_dir, function(filename)
		show_status("🎙️ Recording... (Press " .. (M.config.keymap or ":Vocal") .. " to stop)", 0)
	end, function(error_msg)
		show_error(error_msg)
	end, function(filename)
		show_status("💾 Recording saved", 2000)
	end)
end

function M.get_recording_filename()
	return recording.active_filename
end

return M
