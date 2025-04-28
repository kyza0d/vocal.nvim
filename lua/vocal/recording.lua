-- recording.lua (Modified M.stop_recording)

local Job = require("plenary.job")
local api = require("vocal.api")
local fmt = require("vocal.utils").fmt
local M = {}

local active_job = nil

--- Current recording filename
M.active_filename = nil

--- Checks if recording is active
function M.is_recording() return active_job and not active_job.is_shutdown end

--- Formats recording command
--- @param filename string Output file path
--- @param has_sox boolean Sox availability
local function format_recording_command(filename, has_sox)
  if not has_sox then return nil end
  return fmt("exec sox -q -c 1 -r 44100 -d %s trim 0 3600", vim.fn.shellescape(filename))
end

--- Starts audio recording
--- @param recording_dir string Directory for recordings
--- @param on_start function|nil Callback on start
--- @param on_error function|nil Callback on error
function M.start_recording(recording_dir, on_start, on_error)
  local has_sox = vim.fn.executable("sox") == 1
  if not has_sox then
    if on_error then on_error("Sox is not installed. Please install it to record audio.") end
    return
  end

  if vim.fn.isdirectory(recording_dir) == 0 then vim.fn.mkdir(recording_dir, "p") end
  local filename = fmt("%s/recording_%d.wav", recording_dir, os.time())
  M.active_filename = filename -- Store the expected filename

  local cmd = format_recording_command(filename, has_sox)
  if not cmd then
    M.active_filename = nil -- Clear filename if command fails
    if on_error then on_error("Failed to create recording command") end
    return
  end

  active_job = Job:new({
    command = "bash",
    args = { "-c", cmd },
    on_start = function(job)
      if on_start then on_start(filename) end
      api.debug_log("Started recording:", filename, "Command:", cmd, "PID:", job.pid)
    end,
    on_stderr = function(_, data)
      if data and #data > 0 and data[1] ~= "" then
        local msg = table.concat(data, "\n")
        if
          not msg:match("ALSA")
          and not msg:match("warning")
          and not msg:match("rate")
          and not msg:match("format")
        then
          api.debug_log("Recording stderr:", msg)
          if on_error then on_error(fmt("Recording error: %s", msg)) end
        else
          api.debug_log("Ignored non-critical recording stderr:", msg)
        end
      end
    end,
    on_exit = function(_, code)
      local stopped_filename = filename -- Capture filename from closure
      local job_was_active = active_job -- Capture job state

      if job_was_active and active_job and job_was_active.pid == active_job.pid then
        active_job = nil
        M.active_filename = nil
      end

      local exists, size =
        vim.fn.filereadable(stopped_filename) == 1, vim.fn.getfsize(stopped_filename) or 0
      api.debug_log(
        "Recording process exited:",
        stopped_filename,
        "Exit code:",
        code,
        "File exists:",
        exists,
        "Size:",
        size
      )
    end,
  })

  active_job:start()
  return active_job
end

--- Stops active recording by sending a signal
--- @return string|nil Expected recording filename if a recording was active, nil otherwise.
function M.stop_recording()
  -- Get expected filename before potentially clearing it
  local filename_to_return = M.active_filename
  local job_to_stop = active_job

  if job_to_stop and not job_to_stop.is_shutdown then
    -- Send SIGINT (Ctrl+C), Plenary handles timeout and SIGTERM/SIGKILL if needed.
    -- The '2' is SIGINT. Plenary's shutdown has internal timeout logic.
    job_to_stop:shutdown(2)
    api.debug_log(
      "Sent signal to stop recording process for:",
      filename_to_return,
      "PID:",
      job_to_stop.pid
    )

    active_job = nil
    M.active_filename = nil

    return filename_to_return
  else
    api.debug_log("Stop recording called but no active job found or job already shut down.")
    active_job = nil
    M.active_filename = nil
    return nil
  end
end

--- Gets current recording filename (primarily for debugging or external checks)
--- Returns the filename if a recording job is currently thought to be active.
--- @return string|nil Filename
function M.get_recording_filename() return M.active_filename end

return M
