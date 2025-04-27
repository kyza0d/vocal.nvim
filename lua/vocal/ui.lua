local M = {}

local status_win_id = nil
local status_bufnr = nil
local spinner_timer = nil
local duration_timer = nil
local recording_start_time = nil
local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local current_frame = 1
local current_duration = 0

M.spinner = {
  frames = spinner_frames,
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
  status_win_id = nil
  status_bufnr = nil
  recording_start_time = nil
  current_duration = 0
end

local function format_duration(seconds)
  local minutes = math.floor(seconds / 60)
  local remaining_seconds = seconds % 60
  return string.format("%02d:%02d", minutes, remaining_seconds)
end

local vocal_config = nil

function M.set_config(config) vocal_config = config end

local function get_transcription_method()
  local config = vocal_config or require("vocal.config")
  if config.local_model and config.local_model.model then
    return "Local - " .. config.local_model.model
  else
    return "API"
  end
end

local function create_or_update_window(text)
  if not status_bufnr or not vim.api.nvim_buf_is_valid(status_bufnr) then
    status_bufnr = vim.api.nvim_create_buf(false, true)
  end
  vim.api.nvim_buf_set_lines(status_bufnr, 0, -1, false, { text })
  if not status_win_id or not vim.api.nvim_win_is_valid(status_win_id) then
    local win_config = {
      relative = "editor",
      width = #text + 2,
      height = 1,
      row = vim.o.lines - 2,
      col = vim.o.columns - #text - 4,
      style = "minimal",
      border = "none",
      focusable = false,
    }
    status_win_id = vim.api.nvim_open_win(status_bufnr, false, win_config)

    vim.api.nvim_win_set_option(status_win_id, "winblend", 0)
    vim.api.nvim_win_set_option(status_win_id, "winhighlight", "Normal:Normal")
  else
    vim.api.nvim_win_set_config(status_win_id, {
      relative = "editor",
      width = #text + 2,
      row = vim.o.lines - 2,
      col = vim.o.columns - #text - 4,
    })
  end
end

function M.show_recording_status()
  if not recording_start_time then
    recording_start_time = os.time()
    current_duration = 0
  end

  local method = get_transcription_method()
  local status_text =
    string.format("󰑊 REC  %s  |  Method: %s", format_duration(current_duration), method)
  create_or_update_window(status_text)

  if not duration_timer then
    duration_timer = vim.loop.new_timer()
    duration_timer:start(
      1000,
      1000,
      vim.schedule_wrap(function()
        current_duration = current_duration + 1
        local updated_text = string.format(
          "󰑊 REC  %s  |  Method: %s",
          format_duration(current_duration),
          method
        )
        create_or_update_window(updated_text)
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
  local status_text =
    string.format("%s Transcribing...  |  Method: %s", M.spinner.frames[current_frame], method)
  create_or_update_window(status_text)

  M.spinner.start(function(frame)
    local updated_text = string.format("%s Transcribing...  |  Method: %s", frame, method)
    create_or_update_window(updated_text)
  end)
end

function M.show_error_status(message)
  close_window()
  local status_text = string.format(" %s", message)
  create_or_update_window(status_text)
  vim.defer_fn(function() M.hide_status() end, 3000)
end

function M.show_success_status(message)
  close_window()
  local status_text = string.format(" %s", message)
  create_or_update_window(status_text)
  vim.defer_fn(function() M.hide_status() end, 3000)
end

function M.show_downloading_status(model_name)
  if duration_timer then
    vim.loop.timer_stop(duration_timer)
    duration_timer = nil
  end

  current_frame = 1
  local initial_text =
    string.format("[%s] Downloading model: %s", M.spinner.frames[current_frame], model_name)
  create_or_update_window(initial_text)

  M.spinner.start(function(frame)
    local updated_text = string.format("[%s] Downloading model: %s", frame, model_name)
    create_or_update_window(updated_text)
  end)
end

function M.hide_status() close_window() end

return M
