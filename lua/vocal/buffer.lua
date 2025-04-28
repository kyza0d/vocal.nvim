--- @return string Formatted string
local fmt = require("vocal.utils").fmt

local M = {}

--- Inserts text at cursor in normal mode
--- @param text string Text to insert
function M.insert_at_cursor(text)
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  local cur_line = vim.api.nvim_get_current_line()
  local start, finish = cur_line:sub(1, col), cur_line:sub(col + 1)

  if text:find("\n") then
    local lines = vim.split(text, "\n")
    vim.api.nvim_set_current_line(fmt("%s%s", start, lines[1]))
    local new_lines = { unpack(lines, 2, #lines - 1) }
    new_lines[#new_lines + 1] = fmt("%s%s", lines[#lines], finish)
    vim.api.nvim_buf_set_lines(0, line, line, false, new_lines)
    vim.api.nvim_win_set_cursor(0, { line + #new_lines, #lines[#lines] })
  else
    vim.api.nvim_set_current_line(fmt("%s%s%s", start, text, finish))
    vim.api.nvim_win_set_cursor(0, { line, col + #text })
  end
end

--- Inserts text at cursor
--- @param text string Text to insert
function M.insert_text(text) M.insert_at_cursor(text) end

return M
