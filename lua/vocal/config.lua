local config = {
	api_key = nil,
	recording_dir = os.getenv("HOME") and (os.getenv("HOME") .. "/recordings") or "/tmp/recordings",
	delete_recordings = true, -- Delete recordings after transcription by default

	-- API configuration
	api = {
		model = "whisper-1", -- Default Whisper model
		language = nil, -- Auto-detect language by default
		response_format = "json", -- Return JSON response
		temperature = 0, -- Lower temperature for more deterministic outputs
		timeout = 60, -- Timeout in seconds
	},
}

return config

