---@diagnostic disable: missing-fields
local Job = require("plenary.job")
local M = {}

local active_job = nil
M.active_filename = nil

function M.is_recording()
	return active_job ~= nil and not active_job.is_shutdown
end

function M.start_recording(recording_dir, on_start, on_error, on_stop)
	if vim.fn.executable("sox") == 0 then
		on_error("sox is not installed. Please install sox to record audio.")
		return
	end

	local timestamp = os.time()
	local filename = string.format("%s/recording_%d.wav", recording_dir, timestamp)
	M.active_filename = filename

	active_job = Job:new({
		command = "bash",
		args = {
			"-c",
			string.format("exec sox -q -c 1 -r 44100 -d %s trim 0 3600", vim.fn.shellescape(filename)),
		},
		on_start = function(_)
			on_start(filename)
		end,
		on_exit = function(_, return_val)
			active_job = nil
			if return_val == 0 or return_val == 143 or return_val == 130 then
				on_stop(filename)
			else
				on_error("Recording failed with exit code: " .. return_val)
			end
		end,
	})

	active_job:start()
	return active_job
end

function M.stop_recording()
	if active_job and not active_job.is_shutdown then
		os.execute("pkill -INT -f 'sox -q -c 1 -r 44100 -d'")
		vim.defer_fn(function()
			os.execute("pkill -TERM -f sox || true")
		end, 300)

		active_job = nil
	end

	return M.active_filename
end

function M.get_recording_filename()
	return M.active_filename
end

return M