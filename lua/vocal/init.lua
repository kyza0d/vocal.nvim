local fmt = require("vocal.utils").fmt -- Use fmt for string formatting
local recording = require("vocal.recording")
local ui = require("vocal.ui")
local api = require("vocal.api")
local buffer = require("vocal.buffer")
local Job = require("plenary.job")

local M = {}
M.config = require("vocal.config")

--- Path to the Python transcription script.
--- @type string
local transcribe_path = assert(
  vim.api.nvim_get_runtime_file("lua/vocal/transcribe.py", false)[1],
  "transcribe.py not found in runtime path"
)

--- Resolved API key for transcription (cached after first resolution).
--- @type string|nil
local resolved_api_key = nil

--- Deletes a recording file with platform-specific process cleanup.
--- Uses defer_fn to avoid blocking and allow processes to terminate.
--- @param filename string|nil The path to the recording file to delete.
--- @return boolean True if deletion process was initiated, false if file not found.
local function delete_recording_file(filename)
  if not filename or vim.fn.filereadable(filename) ~= 1 then return false end
  vim.defer_fn(function()
    -- Attempt to kill lingering processes associated with the file
    if vim.fn.has("unix") == 1 or vim.fn.has("mac") == 1 then
      os.execute(fmt("pkill -f %s > /dev/null 2>&1 || true", vim.fn.shellescape(filename)))
    elseif vim.fn.has("win32") == 1 then
      os.execute(
        fmt(
          'taskkill /F /FI "WINDOWTITLE eq *%s*" > nul 2>&1 || exit /b 0',
          vim.fn.fnamemodify(filename, ":t")
        )
      )
    end
    -- Give a short delay for process termination before trying to delete
    vim.defer_fn(function()
      local success, err = os.remove(filename)
      api.debug_log(
        success and fmt("Deleted: %s", filename)
          or fmt("Failed to delete: %s (Error: %s)", filename, err or "unknown")
      )
    end, 200) -- Delay before os.remove
  end, 300) -- Initial delay for pkill/taskkill
  return true
end

--- Processes a local recording using the configured local model.
--- Handles model download status updates via stderr parsing.
--- @param filename string The path to the recording file.
local function process_local_recording(filename)
  local model_cfg = M.config.local_model
  if not model_cfg or not model_cfg.model or not model_cfg.path then
    ui.hide_status()
    return ui.show_error_status("Invalid local model configuration")
  end

  local STATUS_PREFIX = "DOWNLOAD_STATUS:"
  local MSG_ALREADY_DOWNLOADED = "MODEL_ALREADY_DOWNLOADED"
  local MSG_DOWNLOADING_MODEL = "DOWNLOADING_MODEL:"
  local MSG_DOWNLOADING_PROGRESS = "DOWNLOADING_PROGRESS:"
  local MSG_DOWNLOAD_COMPLETE = "MODEL_DOWNLOAD_COMPLETE"
  local download_detected = false -- Only relevant for progress messages logic

  --- Handles stderr lines from the transcription script, looking for download status.
  --- @param _ any Job object (unused).
  --- @param data string|nil Line from stderr.
  --- @return boolean True if the line was a handled status message, false otherwise.
  local function handle_stderr(_, data)
    if not data or type(data) ~= "string" or not data:match(fmt("^%s", STATUS_PREFIX)) then
      api.debug_log(fmt("Ignoring stderr line: %s", tostring(data)))
      return false
    end

    local message = data:gsub(fmt("^%s", STATUS_PREFIX), "")
    vim.schedule(function()
      api.debug_log(fmt("Received download status: %s", message))
      if message:match(MSG_ALREADY_DOWNLOADED) then
        api.debug_log(
          fmt(
            "Script confirms model already downloaded: %s. Setting Transcribing status.",
            model_cfg.model
          )
        )
        ui.start_transcribing_status() -- **NEW:** Set transcribing status *here*
      elseif message:match(fmt("^%s", MSG_DOWNLOADING_MODEL)) then
        download_detected = true
        api.debug_log(
          fmt(
            "Script confirms downloading model: %s",
            message:gsub(fmt("^%s", MSG_DOWNLOADING_MODEL), "")
          )
        )
        ui.show_downloading_status(message:gsub(fmt("^%s", MSG_DOWNLOADING_MODEL), ""))
      elseif message:match(fmt("^%s", MSG_DOWNLOADING_PROGRESS)) then
        ui.show_downloading_status(message:gsub(fmt("^%s", MSG_DOWNLOADING_PROGRESS), ""))
      elseif message:match(MSG_DOWNLOAD_COMPLETE) then
        api.debug_log("Model download complete message received. Setting Transcribing status.")
        ui.start_transcribing_status() -- Switch UI to transcribing
      else
        api.debug_log(fmt("Unhandled DOWNLOAD_STATUS message: %s", message))
      end
    end)
    return true
  end

  --- @param return_val number The exit code of the job.
  local function handle_exit(j, return_val)
    vim.schedule(function()
      ui.hide_status() -- Always hide status on exit
      if return_val == 0 then -- Success
        local text = table
          .concat(j:result() or {}, "\n")
          :gsub("^%s+", "")
          :gsub("%s+$", "")
          :gsub("\r\n", "\n")
        if text ~= "" then
          buffer.insert_at_cursor(text)
        else
          api.debug_log("Transcription returned empty result.")
        end
        local msg = "Transcription complete"
        if M.config.delete_recordings then
          if delete_recording_file(filename) then
            msg = fmt("%s", msg)
            api.debug_log(fmt("Initiated deletion for: %s", filename))
          end
        end
        ui.show_success_status(msg)
      else -- Failure
        local stderr_lines = j:stderr_result() or {}
        local filtered_stderr = {}
        for _, line in ipairs(stderr_lines) do
          if not line:match(fmt("^%s", STATUS_PREFIX)) then
            table.insert(filtered_stderr, line)
          end
        end
        local stderr_output =
          table.concat(filtered_stderr, "\n"):gsub("^\n+", ""):gsub("\n+$", "")
        local err_msg = fmt("Local transcription failed (code: %d)", return_val)
        if stderr_output ~= "" then err_msg = fmt("%s:\n%s", err_msg, stderr_output) end
        ui.show_error_status(err_msg)
        api.debug_log(
          fmt(
            "Transcription job failed. Code: %d. Full Stderr:\n%s",
            return_val,
            table.concat(stderr_lines, "\n")
          )
        )
      end
    end)
  end

  api.debug_log("Starting local transcription job...")
  Job:new({
    command = "python",
    args = { transcribe_path, filename, model_cfg.model, model_cfg.path },

    -- Ignore empty stdout lines
    on_stdout = function(_, data) return not data or data:match("^%s*$") end,
    on_stderr = handle_stderr,
    on_exit = handle_exit,
  }):start()
end

--- Waits for a recording file to stabilize (exist and size stops changing) and then processes it.
--- @param filename string The path to the recording file.
local function process_recording(filename)
  vim.loop.sleep(200) -- Initial brief pause after stop signal

  local attempts = 15 -- Check for ~1.5 seconds total (200ms + 15*100ms)
  local file_ready = false
  local last_size = -1

  for i = 1, attempts do
    local exists = vim.fn.filereadable(filename) == 1
    local current_size = vim.fn.getfsize(filename) or -1
    if exists and current_size > 0 and current_size == last_size then
      file_ready = true
      api.debug_log(fmt("File %s ready after %dms check.", filename, 200 + i * 100))
      break
    end
    last_size = current_size
    if i < attempts then vim.loop.sleep(100) end -- Wait before next check
  end

  if not file_ready then
    api.debug_log(fmt("File %s not found or unstable after %d attempts.", filename, attempts))
    return ui.show_error_status("Recording file processing error (timeout/unstable)")
  end

  -- File is ready, decide transcription path
  if M.config.local_model and M.config.local_model.model and M.config.local_model.path then
    -- Handles its own UI updates
    process_local_recording(filename)
  else
    -- API Transcription Path
    resolved_api_key = resolved_api_key or api.resolve_api_key(M.config.api_key)
    if not resolved_api_key then
      ui.hide_status()
      return ui.show_error_status("OpenAI API key not found")
    end
    api.transcribe(filename, resolved_api_key, function(text)
      vim.schedule(function()
        ui.hide_status()
        text = text:gsub("^%s+", ""):gsub("%s+$", ""):gsub("\r\n", "\n")
        buffer.insert_at_cursor(text)
        local msg = "Transcription complete"
        if M.config.delete_recordings then
          if delete_recording_file(filename) then msg = fmt("%s (recording deleted)", msg) end
        end
        ui.show_success_status(msg)
      end)
    end, function(err)
      vim.schedule(function()
        ui.hide_status()
        ui.show_error_status(fmt("API Transcription failed: %s", err))
      end)
    end)
  end
end

--- Checks if the configured local model file exists.
--- @return boolean|nil True if model exists, False if configured but not found, nil if local model not configured.
local function check_local_model_exists()
  local model_cfg = M.config.local_model
  if not model_cfg or not model_cfg.model or not model_cfg.path then return nil end -- Not configured

  local model_file = fmt("%s/%s.pt", vim.fn.expand(model_cfg.path), model_cfg.model)
  local exists = vim.fn.filereadable(model_file) == 1
  api.debug_log(
    exists and fmt("Local model file found: %s", model_file)
      or fmt("Local model file not found: %s", model_file)
  )
  return exists
end

--- Public setup function for the plugin.
--- Merges user options, sets up API/UI configs, creates command and keymap.
--- @param opts table|nil User configuration options table.
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  if opts and opts.api then api.set_options(opts.api) end
  ui.set_config(M.config)
  vim.api.nvim_create_user_command(
    "Vocal",
    M.transcribe,
    { desc = "Start/stop Vocal recording and transcribe" }
  )
  if M.config.keymap then
    vim.keymap.set(
      "n",
      M.config.keymap,
      ":Vocal<CR>",
      { desc = "Start/stop Vocal recording", silent = true }
    )
  end
  api.debug_log("Vocal setup complete.")
end

--- Toggles recording state or initiates transcription process.
--- This is the main entry point command (:Vocal).
function M.transcribe()
  if recording.is_recording() then
    local filename = recording.stop_recording() -- Non-blocking stop

    if not filename then
      ui.hide_status()
      ui.show_error_status("Failed to stop recording (no active recording found).")
      api.debug_log("M.transcribe: stop_recording returned nil.")
      return -- Exit early
    end

    local model_exists = check_local_model_exists() -- nil, true, or false
    local is_local_configured = model_exists ~= nil

    if is_local_configured then
      if model_exists == false then
        local model_name = M.config.local_model.model or "Unknown Model"
        ui.show_downloading_status(model_name) -- Show "Downloading..." immediately
        api.debug_log(
          fmt("Set immediate status to Downloading (model file not found): %s", model_name)
        )
      else
        ui.start_transcribing_status()
        api.debug_log("Set immediate status to Transcribing (Local model exists)")
      end
    else
      ui.start_transcribing_status()
      api.debug_log("Set immediate status to Transcribing (API path)")
    end

    vim.defer_fn(function()
      api.debug_log(fmt("Deferred processing starting for: %s", filename))
      process_recording(filename) -- This function handles further UI updates if needed (e.g., errors, actual download progress)
    end, 100) -- allows UI update to render
  else
    recording.start_recording(M.config.recording_dir, function(started_filename)
      ui.show_recording_status()
      api.debug_log(fmt("Recording started. UI updated for: %s", started_filename))
    end, function(err)
      ui.show_error_status(fmt("Recording start error: %s", err))
      api.debug_log(fmt("Failed to start recording: %s", err))
    end)
  end
end

--- Gets the filename of the currently active recording, if any.
--- @return string|nil The active recording filename or nil if not recording.
function M.get_recording_filename() return recording.active_filename end

return M
