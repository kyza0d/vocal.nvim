---@diagnostic disable: missing-fields
local curl = require("plenary.curl") -- We'll use this in a future implementation
local Job = require("plenary.job")

local M = {
	debug_mode = false, -- Set to true to enable verbose logging
	log_file = os.getenv("HOME") .. "/.cache/vocal.log",
}

-- Configure API request options
M.options = {
	model = "whisper-1", -- Default Whisper model
	language = nil, -- Auto-detect language by default
	response_format = "json", -- Return JSON response
	temperature = 0, -- Lower temperature for more deterministic outputs
	timeout = 60, -- Timeout in seconds
}

-- Validate API key format
---@param api_key string The API key to validate
---@return boolean is_valid
---@return string? error_message
local function validate_api_key(api_key)
	if not api_key or api_key == "" then
		return false, "API key is empty"
	end

	-- Most OpenAI API keys start with "sk-" and have a specific length
	if not api_key:match("^sk%-") then
		return false, "API key does not have the expected format (should start with 'sk-')"
	end

	-- Basic length check (OpenAI keys are typically longer than 30 chars)
	if #api_key < 30 then
		return false, "API key appears to be too short"
	end

	return true, nil
end

-- Debug log function that writes to file when debug_mode is enabled
local function debug_log(...)
	if M.debug_mode then
		local args = { ... }
		local str_args = {}
		for i, arg in ipairs(args) do
			if type(arg) == "table" then
				str_args[i] = vim.inspect(arg)
			else
				str_args[i] = tostring(arg)
			end
		end

		-- Create timestamp
		local timestamp = os.date("%Y-%m-%d %H:%M:%S")
		local log_message = "[" .. timestamp .. "] " .. table.concat(str_args, " ") .. "\n"

		-- Ensure the directory exists
		local cache_dir = vim.fn.fnamemodify(M.log_file, ":h")
		if vim.fn.isdirectory(cache_dir) == 0 then
			vim.fn.mkdir(cache_dir, "p")
		end

		-- Append to log file
		local file = io.open(M.log_file, "a")
		if file then
			file:write(log_message)
			file:close()
		end
	end
end

-- Send audio file to Whisper API for transcription
---@param filename string Path to the audio file
---@param api_key string OpenAI API key
---@param on_success function Callback for successful transcription
---@param on_error function Callback for errors
function M.transcribe(filename, api_key, on_success, on_error)
	-- Log debug session start
	debug_log("======== NEW TRANSCRIPTION REQUEST ========")

	-- Validate inputs
	if not filename or not api_key then
		local error_msg = "Missing filename or API key"
		debug_log("Error: " .. error_msg)
		on_error(error_msg)
		return
	end

	-- Check if file exists
	if vim.fn.filereadable(filename) ~= 1 then
		local error_msg = "Audio file not found: " .. filename
		debug_log("Error: " .. error_msg)
		on_error(error_msg)
		return
	end

	-- Validate API key format
	local key_valid, key_error = validate_api_key(api_key)
	if not key_valid then
		local error_msg = "Invalid API key: " .. key_error
		debug_log("Error: " .. error_msg)
		on_error(error_msg)
		return
	end

	-- Prepare API options
	local request_options = {}
	for k, v in pairs(M.options) do
		if v ~= nil then
			request_options[k] = v
		end
	end

	-- Log API request attempt (without showing the full key)
	debug_log("Attempting API request with key: " .. api_key:sub(1, 5) .. "..." .. api_key:sub(-4))
	debug_log("File: " .. filename)
	debug_log("Options: ", request_options)

	-- Prepare curl command with proper escaping for the Authorization header
	local curl_cmd = {
		"curl",
		"-v", -- Verbose output for debugging
		"-s", -- Silent mode (no progress bar)
		"-X",
		"POST",
		"-H",
		"Authorization: Bearer " .. api_key,
		"-H",
		"Content-Type: multipart/form-data",
		"-F",
		"file=@" .. filename,
		"-F",
		"model=" .. request_options.model,
	}

	-- Add optional parameters
	if request_options.language then
		table.insert(curl_cmd, "-F")
		table.insert(curl_cmd, "language=" .. request_options.language)
	end

	table.insert(curl_cmd, "-F")
	table.insert(curl_cmd, "response_format=" .. request_options.response_format)

	table.insert(curl_cmd, "-F")
	table.insert(curl_cmd, "temperature=" .. request_options.temperature)

	-- Add API endpoint
	table.insert(curl_cmd, "https://api.openai.com/v1/audio/transcriptions")

	debug_log("Curl command:", curl_cmd)

	-- Execute the API request asynchronously
	Job:new({
		command = curl_cmd[1],
		args = { unpack(curl_cmd, 2) },
		on_exit = function(j, return_val)
			-- Always schedule callbacks to run in the main Neovim loop
			vim.schedule(function()
				local stderr_result = table.concat(j:stderr_result(), "\n")
				local result = table.concat(j:result(), "\n")

				debug_log("API response code:", return_val)
				debug_log("API stderr:", stderr_result)
				debug_log("API response:", result)

				if return_val ~= 0 then
					local error_msg = "API request failed with code: " .. return_val .. "\nDetails: " .. stderr_result
					debug_log("Error: " .. error_msg)
					on_error(error_msg)
					return
				end

				-- Handle empty response
				if not result or result == "" then
					local error_msg = "Empty response from API"
					debug_log("Error: " .. error_msg)
					on_error(error_msg)
					return
				end

				-- Parse JSON response
				local ok, decoded = pcall(vim.json.decode, result)
				if not ok or not decoded then
					local error_msg = "Failed to decode API response: " .. result
					debug_log("Error: " .. error_msg)
					on_error(error_msg)
					return
				end

				-- Check for API error
				if decoded.error then
					local error_msg = "API error: " .. (decoded.error.message or "Unknown API error")
					debug_log("Error: " .. error_msg)
					on_error(error_msg)
					return
				end

				-- Extract transcription
				if decoded.text then
					debug_log("Transcription successful! Length: " .. #decoded.text .. " characters")
					on_success(decoded.text)
				else
					local error_msg = "No transcription found in response"
					debug_log("Error: " .. error_msg)
					on_error(error_msg)
				end
			end)
		end,
		on_stderr = function(_, data)
			if data and #data > 0 then
				debug_log("Stderr data:", data)
			end
		end,
	}):start()
end

-- Set API options
---@param opts table Configuration options
function M.set_options(opts)
	M.options = vim.tbl_deep_extend("force", M.options, opts or {})
end

-- Enable debug mode
function M.enable_debug()
	M.debug_mode = true

	-- Create a header in the log file
	local file = io.open(M.log_file, "a")
	if file then
		file:write("\n\n======== DEBUG MODE ENABLED AT " .. os.date("%Y-%m-%d %H:%M:%S") .. " ========\n")
		file:close()
	end

	vim.notify("Vocal plugin debug mode enabled - Logging to " .. M.log_file, vim.log.levels.INFO)
end

-- Disable debug mode
function M.disable_debug()
	-- Log debug session end
	if M.debug_mode then
		local file = io.open(M.log_file, "a")
		if file then
			file:write("======== DEBUG MODE DISABLED AT " .. os.date("%Y-%m-%d %H:%M:%S") .. " ========\n\n")
			file:close()
		end
	end

	M.debug_mode = false
	vim.notify("Vocal plugin debug mode disabled", vim.log.levels.INFO)
end

return M