local M = {}

local config = require("s3_copy.config")
local util = require("s3_copy.util")

local function get_selection_positions()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  if start_pos[2] == 0 or end_pos[2] == 0 then
    local v_pos = vim.fn.getpos("v")
    local dot_pos = vim.fn.getpos(".")
    if v_pos[2] ~= 0 and dot_pos[2] ~= 0 then
      start_pos = v_pos
      end_pos = dot_pos
    end
  end

  if start_pos[2] == 0 or end_pos[2] == 0 then
    return nil, nil
  end

  return start_pos, end_pos
end

local function get_visual_selection()
  local buf = 0
  local start_pos, end_pos = get_selection_positions()

  if not start_pos or not end_pos then
    return nil, "No visual selection found"
  end

  local start_row, start_col = start_pos[2] - 1, start_pos[3] - 1
  local end_row, end_col = end_pos[2] - 1, end_pos[3] - 1

  if start_row > end_row or (start_row == end_row and start_col > end_col) then
    start_row, end_row = end_row, start_row
    start_col, end_col = end_col, start_col
  end

  local lines = vim.api.nvim_buf_get_text(buf, start_row, start_col, end_row, end_col + 1, {})
  if #lines == 0 then
    return nil, "Selection is empty"
  end

  return table.concat(lines, "\n"), nil
end

local function prompt_bucket(default)
  local value = vim.fn.input("S3 bucket: ", default or "")
  vim.cmd("redraw")
  return value
end

local function prompt_key(default)
  local value = vim.fn.input("S3 key: ", default or "")
  vim.cmd("redraw")
  return value
end

local function ensure_aws_cli()
  if vim.fn.executable("aws") == 1 then
    return true
  end

  vim.notify("aws CLI not found in PATH", vim.log.levels.ERROR)
  return false
end

function M.copy_selection()
  if not ensure_aws_cli() then
    return
  end

  local selection, err = get_visual_selection()
  if not selection then
    vim.notify(err or "Failed to read selection", vim.log.levels.ERROR)
    return
  end

  local bucket = prompt_bucket(config.options.bucket)
  if bucket == "" then
    vim.notify("Bucket is required", vim.log.levels.ERROR)
    return
  end

  local default_key = util.build_default_key(config.options.key_prefix, util.default_filename())
  local key = prompt_key(default_key)
  if key == "" then
    vim.notify("Key is required", vim.log.levels.ERROR)
    return
  end

  local target = util.build_s3_target(bucket, key)
  if not target then
    vim.notify("Invalid bucket or key", vim.log.levels.ERROR)
    return
  end

  local output = vim.fn.system({ "aws", "s3", "cp", "--only-show-errors", "-", target }, selection)
  if vim.v.shell_error ~= 0 then
    local message = vim.trim(output)
    if message == "" then
      message = "S3 copy failed"
    else
      message = "S3 copy failed: " .. message
    end
    vim.notify(message, vim.log.levels.ERROR)
    return
  end

  vim.notify("Copied selection to " .. target, vim.log.levels.INFO)
end

function M.setup()
  vim.api.nvim_create_user_command("S3CopySelection", function()
    M.copy_selection()
  end, {
    desc = "Copy visual selection to S3",
  })
end

return M
