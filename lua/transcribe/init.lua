-- File: lua/transcribe/init.lua
local M = {}
local recording = require("transcribe.recording")
local ui = require("transcribe.ui")
local api = require("transcribe.api")
local buffer = require("transcribe.buffer")

-- Load default configuration
M.config = require("transcribe.config")

-- Cache for the resolved API key
local resolved_api_key = nil

--

-- Spinner configuration
local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local spinner_timer = nil

-- Status message helpers
local function show_status(message, auto_close_delay)
	ui.update_status(message, auto_close_delay)
end

local function show_error(message)
	ui.update_status("❌ " .. message, 5000) -- Auto-close after 5 seconds
end

local function show_info(message, auto_close_delay)
	ui.update_status("📢 " .. message, auto_close_delay or 3000)
end

-- Resolve the API key from config or environment
local function resolve_api_key()
	-- Return cached key if available
	if resolved_api_key then
		return resolved_api_key
	end

	local key = M.config.api_key
	if key == nil then
		-- Try to get from environment
		local env_key = os.getenv("OPENAI_API_KEY")
		if env_key and env_key:match("^%s*(.-)%s*$") ~= "" then
			resolved_api_key = env_key:match("^%s*(.-)%s*$") -- Trim whitespace
		end
	elseif type(key) == "string" then
		-- Directly use string key (trimmed)
		resolved_api_key = key:match("^%s*(.-)%s*$") -- Trim whitespace
	elseif type(key) == "table" then
		-- Execute command to get key
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

	-- Additional validation
	if resolved_api_key then
		-- Basic format check for OpenAI API keys
		if not resolved_api_key:match("^sk%-") then
			show_error("API key doesn't have expected format")
		end

		-- Check length
		if #resolved_api_key < 30 then
			show_error("API key looks too short")
		end
	end

	return resolved_api_key
end

-- Show spinner for transcription
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

-- Process recording with Whisper API
local function process_recording(filename)
	local api_key = resolve_api_key()
	if not api_key then
		show_error("OpenAI API key not found")
		return
	end

	start_spinner("Transcribing audio...")

	api.transcribe(filename, api_key, function(text)
		-- Success callback
		stop_spinner()

		-- Clean up text (trim whitespace, normalize line endings)
		text = text:gsub("^%s+", ""):gsub("%s+$", ""):gsub("\r\n", "\n")

		-- Insert text into buffer
		buffer.insert_text(text)

		show_status("🎙️ Transcription complete", 3000)
	end, function(error_msg)
		-- Error callback
		stop_spinner()
		show_error("Transcription failed: " .. error_msg)

		-- Additional guidance for common errors
		if error_msg:match("API error") then
			vim.defer_fn(function()
				show_info("Enable debug mode with :TranscribeDebug")
			end, 1000)
		end
	end)
end

-- Setup function to initialize the plugin
function M.setup(opts)
	-- Merge user options with defaults
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	-- Configure API options if provided
	if opts and opts.api then
		api.set_options(opts.api)
	end

	-- Define the :Transcribe command
	vim.api.nvim_create_user_command("Transcribe", M.transcribe, {
		range = true,
		desc = "Record audio and transcribe using OpenAI Whisper API",
	})

	-- Register debug commands
	vim.api.nvim_create_user_command("TranscribeDebug", function()
		api.enable_debug()
	end, {
		desc = "Enable debug mode for Transcribe plugin",
	})

	vim.api.nvim_create_user_command("TranscribeNoDebug", function()
		api.disable_debug()
	end, {
		desc = "Disable debug mode for Transcribe plugin",
	})

	vim.api.nvim_create_user_command("TranscribeOpenLog", function()
		if vim.fn.filereadable(api.log_file) == 1 then
			vim.cmd("edit " .. api.log_file)
		else
			show_error("Log file does not exist yet")
		end
	end, {
		desc = "Open the Transcribe debug log file",
	})

	-- Add a test command to verify API connectivity
	vim.api.nvim_create_user_command("TranscribeTestAPI", function()
		local api_key = resolve_api_key()
		if not api_key then
			show_error("No API key found")
			return
		end

		show_status("🔍 Testing API connectivity...", nil) -- No auto-close

		-- Enable debug mode temporarily for this test
		local was_debug_enabled = api.debug_mode
		api.debug_mode = true

		-- Log the test attempt
		local debug_log = function(msg)
			local file = io.open(api.log_file, "a")
			if file then
				file:write("[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] " .. msg .. "\n")
				file:close()
			end
		end

		debug_log("======== API CONNECTIVITY TEST ========")
		debug_log("Testing API connectivity with key: " .. api_key:sub(1, 5) .. "..." .. api_key:sub(-4))

		-- Using curl directly to test connectivity
		local command =
			string.format("curl -s -X GET -H 'Authorization: Bearer %s' https://api.openai.com/v1/models", api_key)

		vim.fn.jobstart(command, {
			on_stdout = function(_, data)
				if data and #data > 0 and data[1] ~= "" then
					local combined_data = table.concat(data, "\n")
					debug_log("API Response: " .. combined_data)

					local success, decoded = pcall(vim.json.decode, combined_data)
					if success and decoded.data then
						show_status("✅ API connection successful!", 5000)
						debug_log("Success: Found " .. #decoded.data .. " models")
					elseif success and decoded.error then
						show_error("API error: " .. (decoded.error.message or "Unknown error"))
						debug_log("Error: " .. (decoded.error.message or "Unknown error"))
					else
						show_error("Failed to decode API response")
						debug_log("Error: Failed to decode API response")
					end
				end
			end,
			on_stderr = function(_, data)
				if data and #data > 0 and data[1] ~= "" then
					local error_msg = table.concat(data, "\n")
					debug_log("Error: " .. error_msg)
					show_error("API connection failed: " .. error_msg)
				end
			end,
			on_exit = function(_, code)
				if code ~= 0 then
					debug_log("Error: API test failed with code: " .. code)
					show_error("API test failed with code: " .. code)
				end

				-- Restore debug mode
				api.debug_mode = was_debug_enabled
				debug_log("======== API TEST COMPLETE ========")
			end,
		})
	end, {
		desc = "Test OpenAI API connectivity",
	})
end

-- Handle the :Transcribe command
function M.transcribe(cmd_opts)
	-- Check for API key
	local api_key = resolve_api_key()
	if not api_key then
		show_error("OpenAI API key not found")
		return
	end

	-- If already recording, stop and process
	if recording.is_recording() then
		local filename = recording.get_recording_filename()

		-- Show stopping status
		show_status("🛑 Stopping recording...")

		-- Try to stop the recording
		recording.stop_recording()

		-- Give it a moment to finalize the recording
		vim.defer_fn(function()
			show_status("📦 Processing recording...", 2000)
			-- Process the recording with Whisper API
			process_recording(filename)
		end, 1000) -- Longer delay to ensure file is fully saved

		return
	end

	-- Start recording
	recording.start_recording(M.config.recording_dir, function(filename)
		-- Show recording indicator
		show_status("🎙️ Recording...")

		-- Create popup for user interaction
		ui.create_recording_popup(function()
			-- On Enter pressed - stop and process
			show_status("🛑 Stopping recording...")

			-- Stop the recording
			recording.stop_recording()

			-- Give it a moment to finalize
			vim.defer_fn(function()
				show_status("📦 Processing recording...", 2000)
				-- Process the recording with Whisper API
				process_recording(filename)
			end, 1000)
		end, function()
			-- On Escape pressed - cancel
			recording.stop_recording()
			show_status("❌ Recording canceled", 3000)
		end)
	end, function(error_msg)
		show_error(error_msg)
	end, function(filename)
		-- Called when recording stops successfully
		show_status("💾 Recording saved", 2000)
	end)
end

-- Helper function to get recording filename - needed by recording.lua
function M.get_recording_filename()
	return recording.active_filename
end

return M
