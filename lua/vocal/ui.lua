local fmt = require("vocal.utils").fmt
local M = {}

--- @type number|nil
local status_win_id, status_bufnr = nil, nil

--- @type userdata|nil
local spinner_timer, duration_timer = nil, nil

--- @type number|nil
local recording_start_time = nil

--- @type table
local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

--- @type number
local current_frame = 1

--- @type number
local current_duration = 0

local highlight_groups = {
  recording_indicator = "VocalRecordingIndicator",
}

local function setup_highlights()
  vim.api.nvim_command(
    fmt("highlight default link %s Exception", highlight_groups.recording_indicator)
  )
end

--- @type table
M.spinner = {
  frames = spinner_frames,
  --- @param update_fn function Callback to update frame
  --- @param interval number|nil Update interval in ms (default: 100)
  --- @return userdata Spinner timer
  start = function(update_fn, interval)
    interval = interval or 100
    if spinner_timer then vim.loop.timer_stop(spinner_timer) end
    current_frame = 1
    spinner_timer = vim.loop.new_timer()
    spinner_timer:start(
      interval,
      interval,
      vim.schedule_wrap(function()
        current_frame = (current_frame % #spinner_frames) + 1
        update_fn(spinner_frames[current_frame])
      end)
    )
    return spinner_timer
  end,
  stop = function()
    if spinner_timer then
      vim.loop.timer_stop(spinner_timer)
      spinner_timer = nil
    end
  end,
  --- @return string Current frame
  get_frame = function() return spinner_frames[current_frame] end,
}

local function close_window()
  M.spinner.stop()
  if duration_timer then
    vim.loop.timer_stop(duration_timer)
    duration_timer = nil
  end
  if status_win_id and vim.api.nvim_win_is_valid(status_win_id) then
    vim.api.nvim_win_close(status_win_id, true)
  end
  status_win_id, status_bufnr, recording_start_time, current_duration = nil, nil, nil, 0
end

--- @param seconds number Duration in seconds
--- @return string Formatted duration
local function format_duration(seconds)
  local minutes = math.floor(seconds / 60)
  return fmt("%02d:%02d", minutes, seconds % 60)
end

--- @type table|nil
local vocal_config = nil

--- @param config table Configuration table
function M.set_config(config)
  vocal_config = config
  -- Setup highlights when configuration is set
  setup_highlights()
end

--- @return string Method description
local function get_transcription_method()
  local config = vocal_config or require("vocal.config")
  return config.local_model
      and config.local_model.model
      and fmt("Local - %s", config.local_model.model)
    or "API"
end

--- @param text string Text to display
--- @param highlight_ranges table|nil Table of highlight ranges {start, end, group}
local function create_or_update_window(text, highlight_ranges)
  if not status_bufnr or not vim.api.nvim_buf_is_valid(status_bufnr) then
    status_bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(status_bufnr, "buftype", "nofile")
  end

  -- Remove any newlines from text to ensure it's a single line
  local sanitized_text = text:gsub("\n", " ")
  vim.api.nvim_buf_set_lines(status_bufnr, 0, -1, false, { sanitized_text })

  local win_config = {
    relative = "editor",
    width = #sanitized_text,
    height = 1,
    col = vim.o.columns - #sanitized_text - 2,
    row = vim.o.lines - 2,
    style = "minimal",
    border = "none",
    focusable = false,
  }

  if not status_win_id or not vim.api.nvim_win_is_valid(status_win_id) then
    status_win_id = vim.api.nvim_open_win(status_bufnr, false, win_config)
    vim.api.nvim_win_set_option(status_win_id, "winblend", 0)
    vim.api.nvim_win_set_option(status_win_id, "winhighlight", "Normal:Normal")
  else
    vim.api.nvim_win_set_config(status_win_id, win_config)
  end

  vim.api.nvim_buf_clear_namespace(status_bufnr, -1, 0, -1)

  if highlight_ranges then
    for _, hl_range in ipairs(highlight_ranges) do
      local start_col, end_col = math.floor(hl_range[1]), math.floor(hl_range[2])
      local hl_group = hl_range[3]

      vim.api.nvim_buf_add_highlight(status_bufnr, -1, hl_group, 0, start_col, end_col)
    end
  end
end

--- Shows recording status
function M.show_recording_status()
  if not recording_start_time then
    recording_start_time, current_duration = os.time(), 0
  end
  local method = get_transcription_method()

  -- Add padding space at the end of the text
  local text = fmt(" 󰑊 REC  %s  |  Method: %s ", format_duration(current_duration), method)

  local highlights = {
    { 1, 4, highlight_groups.recording_indicator },
  }

  create_or_update_window(text, highlights)

  if not duration_timer then
    duration_timer = vim.loop.new_timer()
    duration_timer:start(
      1000,
      1000,
      vim.schedule_wrap(function()
        current_duration = current_duration + 1
        if status_win_id and vim.api.nvim_win_is_valid(status_win_id) then
          local updated_text =
            fmt(" 󰑊 REC  %s  |  Method: %s ", format_duration(current_duration), method)
          create_or_update_window(updated_text, highlights)
        else
          if duration_timer then
            vim.loop.timer_stop(duration_timer)
            duration_timer = nil
          end
        end
      end)
    )
  end
end

function M.start_transcribing_status()
  if duration_timer then
    vim.loop.timer_stop(duration_timer)
    duration_timer = nil
  end
  current_frame = 1
  local method = get_transcription_method()

  local text = fmt("%s Transcribing  |  Method: %s", M.spinner.frames[current_frame], method)

  create_or_update_window(text)

  M.spinner.start(function(frame)
    local updated_text = fmt("%s Transcribing  |  Method: %s", frame, method)
    create_or_update_window(updated_text)
  end)
end

--- @param message string Error message
function M.show_error_status(message)
  close_window()
  local text = fmt(" %s", message)
  create_or_update_window(text)
  vim.defer_fn(function() M.hide_status() end, 3000)
end

--- @param message string Success message
function M.show_success_status(message)
  close_window()
  local text = fmt(" %s", message)
  create_or_update_window(text)
  vim.defer_fn(function() M.hide_status() end, 3000)
end

--- @param model_name string Model name
function M.show_downloading_status(model_name)
  if duration_timer then
    vim.loop.timer_stop(duration_timer)
    duration_timer = nil
  end
  current_frame = 1

  local text = fmt("%s Downloading model: %s", M.spinner.frames[current_frame], model_name)

  create_or_update_window(text)

  M.spinner.start(function(frame)
    local updated_text = fmt("%s Downloading model: %s", frame, model_name)
    create_or_update_window(updated_text)
  end)
end

function M.hide_status() close_window() end

return M
