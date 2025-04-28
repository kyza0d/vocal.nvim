local curl = require("plenary.curl")
local fmt = require("vocal.utils").fmt

--- Module configuration and API interaction
--- @class Vocal
local M = {
  --- Enable debug logging
  --- @type boolean
  debug_mode = true,

  --- Path to log file
  --- @type string
  log_file = fmt("%s/.cache/vocal.log", os.getenv("HOME")),

  --- API request options
  --- @type table
  options = {
    model = "whisper-1",
    language = nil,
    response_format = "json",
    temperature = 0,
    timeout = 60,
  },
}

--- Validate API key format
--- @param api_key string|nil API key to validate
--- @return boolean is_valid Whether key is valid
--- @return string|nil error_msg Error message if invalid
local function validate_api_key(api_key)
  if not api_key or api_key == "" then return false, "API key is empty" end
  if not api_key:match("^sk%-") then return false, "API key must start with 'sk-'" end
  if #api_key < 30 then return false, "API key too short" end
  return true, nil
end

--- Log debug messages to file
--- @param ... any Arguments to log
function M.debug_log(...)
  if not M.debug_mode then return end
  local args = vim.tbl_map(
    function(arg) return type(arg) == "table" and vim.inspect(arg) or tostring(arg) end,
    { ... }
  )
  local log_message = fmt("[%s] %s\n", os.date("%Y-%m-%d %H:%M:%S"), table.concat(args, " "))
  local cache_dir = vim.fn.fnamemodify(M.log_file, ":h")
  if vim.fn.isdirectory(cache_dir) == 0 then vim.fn.mkdir(cache_dir, "p") end
  local file = io.open(M.log_file, "a")
  if file then
    file:write(log_message)
    file:close()
  end
end

--- Resolve API key from config or environment
--- @param config_key string|table|nil Configuration key
--- @return string|nil api_key Resolved API key
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
    if vim.v.shell_error == 0 and #output > 0 then return output[1]:match("^%s*(.-)%s*$") end
  end
  return nil
end

--- Transcribe audio file using OpenAI API
--- @param filename string Audio file path
--- @param api_key string API key
--- @param on_success fun(text: string) Success callback
--- @param on_error fun(err: string) Error callback
function M.transcribe(filename, api_key, on_success, on_error)
  M.debug_log("======== NEW TRANSCRIPTION REQUEST ========")
  if not filename or not api_key then
    M.debug_log("Error: Missing filename or API key")
    return on_error("Missing filename or API key")
  end
  if vim.fn.filereadable(filename) ~= 1 then
    M.debug_log("Error: Audio file not found: %s", filename)
    return on_error(fmt("Audio file not found: %s", filename))
  end
  local key_valid, key_error = validate_api_key(api_key)
  if not key_valid then
    M.debug_log("Error: Invalid API key: %s", key_error)
    return on_error(fmt("Invalid API key: %s", key_error))
  end

  local request_options = vim.tbl_filter(function(v) return v ~= nil end, M.options)
  M.debug_log("Attempting API request with key: %s...%s", api_key:sub(1, 5), api_key:sub(-4))
  M.debug_log("File: %s Options: %s", filename, vim.inspect(request_options))

  local curl_args = {
    "--silent",
    "--show-error",
    "--request",
    "POST",
    "--header",
    fmt("Authorization: Bearer %s", api_key),
    "--form",
    fmt("file=@%s", filename),
    "--form",
    fmt("model=%s", request_options.model),
    "--form",
    fmt("response_format=%s", request_options.response_format),
    "--form",
    fmt("temperature=%s", request_options.temperature),
  }
  if request_options.language then
    curl_args[#curl_args + 1] = "--form"
    curl_args[#curl_args + 1] = fmt("language=%s", request_options.language)
  end

  M.debug_log("Curl arguments: %s", vim.inspect(curl_args))
  curl.post("https://api.openai.com/v1/audio/transcriptions", {
    raw = curl_args,
    timeout = request_options.timeout,
    callback = vim.schedule_wrap(function(response)
      if not response or not response.status then
        M.debug_log("Error: Failed to make API request")
        return on_error("Failed to make API request")
      end
      M.debug_log("API response status: %s Body: %s", response.status, response.body)
      if response.status ~= 200 then
        M.debug_log("Error: API request failed with status: %s", response.status)
        return on_error(fmt("API request failed with status: %s", response.status))
      end
      if not response.body or response.body == "" then
        M.debug_log("Error: Empty response from API")
        return on_error("Empty response from API")
      end
      local ok, decoded = pcall(vim.json.decode, response.body)
      if not ok or not decoded then
        M.debug_log("Error: Failed to decode API response: %s", response.body)
        return on_error(fmt("Failed to decode API response: %s", response.body))
      end
      if decoded.error then
        M.debug_log("Error: API error: %s", decoded.error.message or "Unknown API error")
        return on_error(fmt("API error: %s", decoded.error.message or "Unknown API error"))
      end
      if decoded.text then
        M.debug_log("Transcription successful! Length: %d characters", #decoded.text)
        on_success(decoded.text)
      else
        M.debug_log("Error: No transcription found in response")
        on_error("No transcription found in response")
      end
    end),
  })
end

--- Test API connectivity
--- @param api_key string API key
--- @param callback fun(msg: string, type: string) Result callback
function M.test_api_connectivity(api_key, callback)
  local was_debug_enabled = M.debug_mode
  M.debug_mode = true
  M.debug_log("======== API CONNECTIVITY TEST ========")
  M.debug_log("Testing API connectivity with key: %s...%s", api_key:sub(1, 5), api_key:sub(-4))
  local command = fmt(
    "curl -s -X GET -H 'Authorization: Bearer %s' https://api.openai.com/v1/models",
    api_key
  )
  vim.fn.jobstart(command, {
    on_stdout = function(_, data)
      if data and #data > 0 and data[1] ~= "" then
        local combined_data = table.concat(data, "\n")
        M.debug_log("API Response: %s", combined_data)
        local success, decoded = pcall(vim.json.decode, combined_data)
        if success and decoded.data then
          callback("API connection successful!", "info")
          M.debug_log("Success: Found %d models", #decoded.data)
        elseif success and decoded.error then
          callback(fmt("API error: %s", decoded.error.message or "Unknown error"), "error")
          M.debug_log("Error: %s", decoded.error.message or "Unknown error")
        else
          callback("Failed to decode API response", "error")
          M.debug_log("Error: Failed to decode API response")
        end
      end
    end,
    on_stderr = function(_, data)
      if data and #data > 0 and data[1] ~= "" then
        local error_msg = table.concat(data, "\n")
        M.debug_log("Error: %s", error_msg)
        callback(fmt("API connection failed: %s", error_msg), "error")
      end
    end,
    on_exit = function(_, code)
      if code ~= 0 then
        M.debug_log("Error: API test failed with code: %d", code)
        callback(fmt("API test failed with code: %d", code), "error")
      end
      M.debug_mode = was_debug_enabled
      M.debug_log("======== API TEST COMPLETE ========")
    end,
  })
end

--- Set API options
--- @param opts table|nil Options to merge
function M.set_options(opts) M.options = vim.tbl_deep_extend("force", M.options, opts or {}) end

--- Enable debug mode
function M.enable_debug()
  M.debug_mode = true
  local file = io.open(M.log_file, "a")
  if file then
    file:write(
      fmt("\n\n======== DEBUG MODE ENABLED AT %s ========\n", os.date("%Y-%m-%d %H:%M:%S"))
    )
    file:close()
  end
  vim.notify(
    fmt("Vocal plugin debug mode enabled - Logging to %s", M.log_file),
    vim.log.levels.INFO
  )
end

--- Disable debug mode
function M.disable_debug()
  if M.debug_mode then
    local file = io.open(M.log_file, "a")
    if file then
      file:write(
        fmt("======== DEBUG MODE DISABLED AT %s ========\n\n", os.date("%Y-%m-%d %H:%M:%S"))
      )
      file:close()
    end
  end
  M.debug_mode = false
  vim.notify("Vocal plugin debug mode disabled", vim.log.levels.INFO)
end

return M
