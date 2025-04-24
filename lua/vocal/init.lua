local M = {}

local recording = require("vocal.recording")
local ui = require("vocal.ui")
local api = require("vocal.api")
local buffer = require("vocal.buffer")
local Job = require("plenary.job")
M.config = require("vocal.config")

local transcribe_paths = vim.api.nvim_get_runtime_file("lua/vocal/transcribe.py", false)
if #transcribe_paths == 0 then
	error("transcribe.py not found in runtimepath")
end
local transcribe_path = transcribe_paths[1]

local resolved_api_key = nil

local function delete_recording_file(filename)
	if not filename or vim.fn.filereadable(filename) ~= 1 then
		return false
	end

	vim.defer_fn(function()
		if vim.fn.has("unix") == 1 or vim.fn.has("mac") == 1 then
			os.execute("pkill -f " .. vim.fn.shellescape(filename) .. " > /dev/null 2>&1 || true")
		elseif vim.fn.has("win32") == 1 then
			os.execute(
				'taskkill /F /FI "WINDOWTITLE eq *'
					.. vim.fn.fnamemodify(filename, ":t")
					.. '*" > nul 2>&1 || exit /b 0'
			)
		end

		vim.defer_fn(function()
			local success = os.remove(filename)
			if success then
				api.debug_log("Deleted:", filename)
			else
				api.debug_log("Failed to delete:", filename)
			end
		end, 200)
	end, 300)

	return true
end

local function wait_for_file(filename, max_attempts, interval)
	for _ = 1, max_attempts do
		if vim.fn.filereadable(filename) == 1 then
			return true
		end
		vim.loop.sleep(interval)
	end
	return false
end

local function process_local_recording(filename)
	local model_cfg = M.config.local_model
	if not model_cfg or not model_cfg.model or not model_cfg.path then
		ui.show_error_status("Invalid local model configuration")
		return
	end

	ui.start_transcribing_status()
	Job:new({
		command = "python",
		args = { transcribe_path, filename, model_cfg.model, model_cfg.path },
		on_exit = function(j, return_val)
			vim.schedule(function()
				ui.hide_status()
				if return_val == 0 then
					local text = table.concat(j:result(), "\n"):gsub("^%s+", ""):gsub("%s+$", ""):gsub("\r\n", "\n")
					buffer.insert_at_cursor(text)
					local msg = "Transcription complete"
					if M.config.delete_recordings then
						delete_recording_file(filename)
						ui.show_success_status(msg .. " (cleanup scheduled)")
					else
						ui.show_success_status(msg)
					end
				else
					ui.show_error_status("Local transcription failed: " .. table.concat(j:stderr_result(), "\n"))
				end
			end)
		end,
	}):start()
end

local function process_recording(filename)
	if not wait_for_file(filename, 10, 100) then
		ui.show_error_status("Recording file not found")
		return
	end

	if M.config.local_model and M.config.local_model.model and M.config.local_model.path then
		process_local_recording(filename)
		return
	end

	local api_key = resolved_api_key or api.resolve_api_key(M.config.api_key)
	if not api_key then
		ui.show_error_status("OpenAI API key not found")
		return
	end

	ui.start_transcribing_status()
	api.transcribe(filename, api_key, function(text)
		vim.schedule(function()
			ui.hide_status()
			text = text:gsub("^%s+", ""):gsub("%s+$", ""):gsub("\r\n", "\n")
			buffer.insert_at_cursor(text)

			local msg = "Transcription complete"
			if M.config.delete_recordings then
				delete_recording_file(filename)
				ui.show_success_status(msg .. " (cleanup scheduled)")
			else
				ui.show_success_status(msg)
			end
		end)
	end, function(err)
		vim.schedule(function()
			ui.hide_status()
			ui.show_error_status("Transcription failed: " .. err)
		end)
	end)
end

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
	if opts and opts.api then
		api.set_options(opts.api)
	end

	vim.api.nvim_create_user_command("Vocal", M.transcribe, { desc = "Start or stop audio recording and transcribe" })

	if M.config.keymap then
		vim.keymap.set("n", M.config.keymap, ":Vocal<CR>", { desc = "Start/stop Vocal recording", silent = true })
	end
end

function M.transcribe()
	if recording.is_recording() then
		ui.show_recording_status()
		local filename = recording.stop_recording()
		vim.defer_fn(function()
			if filename then
				process_recording(filename)
			else
				ui.show_error_status("No recording to process")
			end
		end, 500)
	else
		recording.start_recording(M.config.recording_dir, function()
			ui.show_recording_status()
		end, function(err)
			ui.show_error_status("Recording error: " .. err)
		end)
	end
end

function M.get_recording_filename()
	return recording.active_filename
end

return M
