# Updated lua/vocal/config.lua
local config = {
  api_key = nil,
  recording_dir = os.getenv("HOME") and (os.getenv("HOME") .. "/recordings") or "/tmp/recordings",
  delete_recordings = true,
  keymap = "<leader>v",
  local_model = nil, -- { model = "tiny", path = "/path/to/tiny.pt" }
  api = {
    model = "whisper-1",
    language = nil,
    response_format = "json",
    temperature = 0,
    timeout = 60,
  },
}

return config
