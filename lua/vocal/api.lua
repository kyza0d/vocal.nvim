local curl = require("plenary.curl")

local M = {
	debug_mode = true,
	log_file = os.getenv("HOME") .. "/.cache/vocal.log",
}

M.options = {
	model = "whisper-1",
	language = nil,
	response_format = "json",
	temperature = 0,
	timeout = 60,
}

local function validate_api_key(api_key)
	if not api_key or api_key == "" then
		return false, "API key is empty"
	end
	if not api_key:match("^sk%-") then
		return false, "API key does not have the expected format (should start with 'sk-')"
	end
	if #api_key < 30 then
		return false, "API key appears to be too short"
	end
	return true, nil
end

function M.debug_log(...)
	if not M.debug_mode then
		return
	end
	local args = { ... }
	local str_args = {}
	for i, arg in ipairs(args) do
		str_args[i] = type(arg) == "table" and vim.inspect(arg) or tostring(arg)
	end
	local timestamp = os.date("%Y-%m-%d %H:%M:%S")
	local log_message = "[" .. timestamp .. "] " .. table.concat(str_args, " ") .. "\n"
	local cache_dir = vim.fn.fnamemodify(M.log_file, ":h")
	if vim.fn.isdirectory(cache_dir) == 0 then
		vim.fn.mkdir(cache_dir, "p")
	end
	local file = io.open(M.log_file, "a")
	if file then
		file:write(log_message)
		file:close()
	end
end

function M.resolve_api_key(config_key)
	if config_key == nil then
		local env_key = os.getenv("OPENAI_API_KEY")
		if env_key and env_key:match("^%s*(.-)%s*$") ~= "" then
			return env_key:match("^%s*(.-)%s*$")
		end
	elseif type(config_key) == "string" then
		return config_key:match("^%s*(.-)%s*$")
	elseif type(config_key) == "table" then
		local cmd, args = config_key[1], { unpack(config_key, 2) }
		local output = vim.fn.systemlist({ cmd, unpack(args) })
		if vim.v.shell_error == 0 and #output > 0 then
			return output[1]:gsub("^%s*(.-)%s*$", "%1")
		end
	end
	return nil
end

function M.transcribe(filename, api_key, on_success, on_error)
	M.debug_log("======== NEW TRANSCRIPTION REQUEST ========")
	if not filename or not api_key then
		local error_msg = "Missing filename or API key"
		M.debug_log("Error: " .. error_msg)
		on_error(error_msg)
		return
	end
	if vim.fn.filereadable(filename) ~= 1 then
		local error_msg = "Audio file not found: " .. filename
		M.debug_log("Error: " .. error_msg)
		on_error(error_msg)
		return
	end
	local key_valid, key_error = validate_api_key(api_key)
	if not key_valid then
		local error_msg = "Invalid API key: " .. key_error
		M.debug_log("Error: " .. error_msg)
		on_error(error_msg)
		return
	end

	-- Create request_options from M.options
	local request_options = {}
	for k, v in pairs(M.options) do
		if v ~= nil then
			request_options[k] = v
		end
	end

	M.debug_log("Attempting API request with key: " .. api_key:sub(1, 5) .. "..." .. api_key:sub(-4))
	M.debug_log("File: " .. filename, "Options: ", request_options)

	-- Prepare raw curl arguments for multipart form request
	local curl_args = {
		"--silent",
		"--show-error",
		"--request",
		"POST",
		"--header",
		"Authorization: Bearer " .. api_key,
		"--form",
		"file=@" .. filename,
		"--form",
		"model=" .. request_options.model,
		"--form",
		"response_format=" .. request_options.response_format,
		"--form",
		"temperature=" .. tostring(request_options.temperature),
	}
	if request_options.language then
		table.insert(curl_args, "--form")
		table.insert(curl_args, "language=" .. request_options.language)
	end

	M.debug_log("Curl arguments:", curl_args)

	-- Make POST request using plenary.curl with raw arguments
	curl.post("https://api.openai.com/v1/audio/transcriptions", {
		raw = curl_args,
		timeout = request_options.timeout,
		callback = vim.schedule_wrap(function(response)
			if not response or not response.status then
				local error_msg = "Failed to make API request"
				M.debug_log("Error: " .. error_msg)
				on_error(error_msg)
				return
			end
			M.debug_log("API response status:", response.status, "Body:", response.body)
			if response.status ~= 200 then
				local error_msg = "API request failed with status: " .. response.status
				M.debug_log("Error: " .. error_msg)
				on_error(error_msg)
				return
			end
			if not response.body or response.body == "" then
				local error_msg = "Empty response from API"
				M.debug_log("Error: " .. error_msg)
				on_error(error_msg)
				return
			end
			local ok, decoded = pcall(vim.json.decode, response.body)
			if not ok or not decoded then
				local error_msg = "Failed to decode API response: " .. response.body
				M.debug_log("Error: " .. error_msg)
				on_error(error_msg)
				return
			end
			if decoded.error then
				local error_msg = "API error: " .. (decoded.error.message or "Unknown API error")
				M.debug_log("Error: " .. error_msg)
				on_error(error_msg)
				return
			end
			if decoded.text then
				M.debug_log("Transcription successful! Length: " .. #decoded.text .. " characters")
				on_success(decoded.text)
			else
				local error_msg = "No transcription found in response"
				M.debug_log("Error: " .. error_msg)
				on_error(error_msg)
			end
		end),
	})
end

function M.test_api_connectivity(api_key, callback)
	local was_debug_enabled = M.debug_mode
	M.debug_mode = true
	M.debug_log("======== API CONNECTIVITY TEST ========")
	M.debug_log("Testing API connectivity with key: " .. api_key:sub(1, 5) .. "..." .. api_key:sub(-4))
	local command =
		string.format("curl -s -X GET -H 'Authorization: Bearer %s' https://api.openai.com/v1/models", api_key)
	vim.fn.jobstart(command, {
		on_stdout = function(_, data)
			if data and #data > 0 and data[1] ~= "" then
				local combined_data = table.concat(data, "\n")
				M.debug_log("API Response: " .. combined_data)
				local success, decoded = pcall(vim.json.decode, combined_data)
				if success and decoded.data then
					callback("API connection successful!", "info")
					M.debug_log("Success: Found " .. #decoded.data .. " models")
				elseif success and decoded.error then
					callback("API error: " .. (decoded.error.message or "Unknown error"), "error")
					M.debug_log("Error: " .. (decoded.error.message or "Unknown error"))
				else
					callback("Failed to decode API response", "error")
					M.debug_log("Error: Failed to decode API response")
				end
			end
		end,
		on_stderr = function(_, data)
			if data and #data > 0 and data[1] ~= "" then
				local error_msg = table.concat(data, "\n")
				M.debug_log("Error: " .. error_msg)
				callback("API connection failed: " .. error_msg, "error")
			end
		end,
		on_exit = function(_, code)
			if code ~= 0 then
				M.debug_log("Error: API test failed with code: " .. code)
				callback("API test failed with code: " .. code, "error")
			end
			M.debug_mode = was_debug_enabled
			M.debug_log("======== API TEST COMPLETE ========")
		end,
	})
end

function M.set_options(opts)
	M.options = vim.tbl_deep_extend("force", M.options, opts or {})
end

function M.enable_debug()
	M.debug_mode = true
	local file = io.open(M.log_file, "a")
	if file then
		file:write("\n\n======== DEBUG MODE ENABLED AT " .. os.date("%Y-%m-%d %H:%M:%S") .. " ========\n")
		file:close()
	end
	vim.notify("Vocal plugin debug mode enabled - Logging to " .. M.log_file, vim.log.levels.INFO)
end

function M.disable_debug()
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
