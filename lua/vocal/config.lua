local fmt = require("vocal.utils").fmt

--- Plugin configuration settings
--- @class Config
--- @field api_key string|table|nil OpenAI API key (string, command table, or nil for env var)
--- @field recording_dir string Directory for audio recordings
--- @field delete_recordings boolean Delete recordings after transcription
--- @field keymap string|nil Keybinding for :Vocal command
--- @field local_model table|nil Local Whisper model settings
--- @field api table API configuration for OpenAI Whisper
--- @field ui table UI settings for status display
local config = {
  api_key = nil,
  recording_dir = os.getenv("HOME") and fmt("%s/recordings", os.getenv("HOME"))
    or "/tmp/recordings",
  delete_recordings = true,
  keymap = "<leader>v",
  local_model = {
    model = "tiny",
    path = os.getenv("HOME") and fmt("%s/.cache/vocal/models", os.getenv("HOME"))
      or "/tmp/vocal_models",
  },
  api = {
    model = "whisper-1",
    language = nil,
    response_format = "json",
    temperature = 0,
    timeout = 60,
  },
  ui = {
    update_interval = 1000,
    display_time = 3000,
  },
}

--- Ensures directory exists
--- @param dir string Directory path
--- @return boolean Success status
local function ensure_dir_exists(dir) return os.execute(fmt('mkdir -p "%s"', dir)) end

--- Initializes plugin by creating recording directory
local function init() ensure_dir_exists(config.recording_dir) end

init()

return config
