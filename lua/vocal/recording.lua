local Job = require("plenary.job")
local api = require("vocal.api")
local M = {}

local active_job = nil
M.active_filename = nil

function M.is_recording() return active_job ~= nil and not active_job.is_shutdown end

local function format_recording_command(filename, has_sox)
  local escaped_filename = vim.fn.shellescape(filename)

  if has_sox then
    return string.format("exec sox -q -c 1 -r 44100 -d %s trim 0 3600", escaped_filename)
  end

  return nil
end

function M.start_recording(recording_dir, on_start, on_error, on_stop)
  local has_sox = vim.fn.executable("sox") == 1

  if not has_sox then
    if on_error then on_error("Sox is not installed. Please install it to record audio.") end
    return
  end

  if vim.fn.isdirectory(recording_dir) == 0 then vim.fn.mkdir(recording_dir, "p") end

  local timestamp = os.time()
  local extension = ".wav"
  local filename = string.format("%s/recording_%d%s", recording_dir, timestamp, extension)
  M.active_filename = filename

  local cmd = format_recording_command(filename, has_sox)
  if not cmd then
    if on_error then on_error("Failed to create recording command") end
    return
  end

  active_job = Job:new({
    command = "bash",
    args = { "-c", cmd },
    on_start = function(_)
      if on_start then on_start(filename) end
      api.debug_log("Started recording:", filename, "Command:", cmd)
    end,
    on_stderr = function(_, data)
      if data and #data > 0 and data[1] ~= "" then
        local stderr_msg = table.concat(data, "\n")
        if not stderr_msg:match("ALSA") and not stderr_msg:match("warning") then
          api.debug_log("Recording stderr:", stderr_msg)
          if on_error then on_error("Recording error: " .. stderr_msg) end
        else
          api.debug_log("Ignored non-critical recording stderr:", stderr_msg)
        end
      end
    end,
    on_exit = function(_, return_val)
      active_job = nil
      local file_exists = vim.fn.filereadable(filename) == 1
      local file_size = file_exists and vim.fn.getfsize(filename) or 0
      api.debug_log(
        "Recording stopped:",
        filename,
        "Exit code:",
        return_val,
        "File exists:",
        file_exists,
        "Size:",
        file_size
      )
      if
        return_val == 0
        or return_val == 143
        or return_val == 130
        or (return_val == 2 and file_exists)
        or (return_val == 1 and file_exists and file_size > 0)
      then
        if on_stop then on_stop(filename) end
        api.debug_log("Recording processed successfully:", filename)
      else
        local err_msg = "Recording failed with exit code: " .. return_val
        api.debug_log("Recording failed:", filename, err_msg)
        if on_error then on_error(err_msg) end
      end
    end,
  })

  active_job:start()
  return active_job
end

function M.stop_recording()
  if active_job and not active_job.is_shutdown then
    active_job:shutdown(2) -- SIGINT
    vim.loop.sleep(1500)
    api.debug_log("Sent signal to stop recording:", M.active_filename)
  end

  local filename = M.active_filename
  active_job = nil
  M.active_filename = nil
  if filename and vim.fn.filereadable(filename) == 1 then
    local last_size = -1
    for _ = 1, 10 do
      local current_size = vim.fn.getfsize(filename)
      if current_size == last_size and current_size > 0 then return filename end
      last_size = current_size
      vim.loop.sleep(100)
    end
    api.debug_log("Recording file empty or unstable:", filename)
    return nil
  else
    api.debug_log("Recording file not found:", filename)
    return nil
  end
end

function M.get_recording_filename() return M.active_filename end

return M
