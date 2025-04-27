local config = {
  api_key = nil,
  recording_dir = (
    os.getenv("HOME") and (os.getenv("HOME") .. "/recordings") or "/tmp/recordings"
  ),
  delete_recordings = true,
  keymap = "<leader>v",
  local_model = {
    model = "tiny",
    path = (
      os.getenv("HOME") and (os.getenv("HOME") .. "/.cache/vocal/models")
      or "/tmp/vocal_models"
    ),
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

local function ensure_dir_exists(dir)
  local success = os.execute('mkdir -p "' .. dir .. '"')
  return success
end

local function init() ensure_dir_exists(config.recording_dir) end

init()

return config
