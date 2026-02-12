local M = {}

local config = require("s3_copy.config")
local util = require("s3_copy.util")

local function prompt_input(prompt, default, callback)
  vim.ui.input({ prompt = prompt, default = default or "" }, function(value)
    callback(value)
  end)
end

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

local function ensure_aws_cli()
  if vim.fn.executable("aws") == 1 then
    return true
  end

  vim.notify("aws CLI not found in PATH", vim.log.levels.ERROR)
  return false
end

local function stat_path(path)
  if not path or path == "" then
    return nil
  end

  return vim.loop.fs_stat(path)
end

local function normalize_path(path)
  if not path or path == "" then
    return nil
  end

  return vim.fn.fnamemodify(vim.fn.expand(path), ":p")
end

local function prompt_bucket_and_key(default_key, callback)
  prompt_input("S3 bucket: ", config.options.bucket, function(bucket)
    if bucket == nil then
      return
    end

    if not bucket or bucket == "" then
      vim.notify("Bucket is required", vim.log.levels.ERROR)
      return
    end

    prompt_input("S3 key: ", default_key, function(key)
      if key == nil then
        return
      end

      if not key or key == "" then
        vim.notify("Key is required", vim.log.levels.ERROR)
        return
      end

      local target = util.build_s3_target(bucket, key)
      if not target then
        vim.notify("Invalid bucket or key", vim.log.levels.ERROR)
        return
      end

      callback(target)
    end)
  end)
end

local function run_aws_cp(args, input)
  local output = vim.fn.system(args, input)
  if vim.v.shell_error ~= 0 then
    local message = vim.trim(output)
    if message == "" then
      message = "S3 copy failed"
    else
      message = "S3 copy failed: " .. message
    end
    vim.notify(message, vim.log.levels.ERROR)
    return false
  end

  return true
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

  local default_key = util.build_default_key(config.options.key_prefix, util.default_filename())

  prompt_bucket_and_key(default_key, function(target)
    local ok = run_aws_cp({ "aws", "s3", "cp", "--only-show-errors", "-", target }, selection)
    if ok then
      vim.notify("Copied selection to " .. target, vim.log.levels.INFO)
    end
  end)
end

function M.copy_file(path)
  if not ensure_aws_cli() then
    return
  end

  local default_path = vim.api.nvim_buf_get_name(0)
  if default_path ~= "" then
    default_path = vim.fn.fnamemodify(default_path, ":p")
  else
    default_path = nil
  end

  local function proceed(resolved_path)
    if not resolved_path or resolved_path == "" then
      vim.notify("File path is required", vim.log.levels.ERROR)
      return
    end

    local stat = stat_path(resolved_path)
    if not stat or stat.type ~= "file" then
      vim.notify("File not found: " .. resolved_path, vim.log.levels.ERROR)
      return
    end

    local rel_path = vim.fn.fnamemodify(resolved_path, ":.")
    local default_key = util.build_default_key(
      config.options.key_prefix,
      util.default_filename_for_path(rel_path)
    )

    prompt_bucket_and_key(default_key, function(target)
      local ok = run_aws_cp({ "aws", "s3", "cp", "--only-show-errors", resolved_path, target })
      if ok then
        vim.notify("Copied file to " .. target, vim.log.levels.INFO)
      end
    end)
  end

  if path and path ~= "" then
    proceed(normalize_path(path))
  else
    prompt_input("File path: ", default_path, function(value)
      if value == nil then
        return
      end
      proceed(normalize_path(value))
    end)
  end
end

function M.copy_dir(path)
  if not ensure_aws_cli() then
    return
  end

  local bufname = vim.api.nvim_buf_get_name(0)
  local default_path
  if bufname ~= "" then
    default_path = vim.fn.fnamemodify(bufname, ":p:h")
  else
    default_path = vim.fn.getcwd()
  end

  local function proceed(resolved_path)
    if not resolved_path or resolved_path == "" then
      vim.notify("Directory path is required", vim.log.levels.ERROR)
      return
    end

    local stat = stat_path(resolved_path)
    if not stat or stat.type ~= "directory" then
      vim.notify("Directory not found: " .. resolved_path, vim.log.levels.ERROR)
      return
    end

    local rel_path = vim.fn.fnamemodify(resolved_path, ":.")
    local default_key = util.build_default_key(
      config.options.key_prefix,
      util.default_dir_key(rel_path)
    )

    prompt_bucket_and_key(default_key, function(target)
      local ok = run_aws_cp({
        "aws",
        "s3",
        "cp",
        "--only-show-errors",
        "--recursive",
        resolved_path,
        target,
      })
      if ok then
        vim.notify("Copied directory to " .. target, vim.log.levels.INFO)
      end
    end)
  end

  if path and path ~= "" then
    proceed(normalize_path(path))
  else
    prompt_input("Directory path: ", default_path, function(value)
      if value == nil then
        return
      end
      proceed(normalize_path(value))
    end)
  end
end

function M.setup()
  vim.api.nvim_create_user_command("S3CopySelection", function()
    M.copy_selection()
  end, {
    desc = "Copy visual selection to S3",
  })

  vim.api.nvim_create_user_command("S3CopyFile", function(opts)
    local path = opts.args ~= "" and opts.args or nil
    M.copy_file(path)
  end, {
    nargs = "?",
    complete = "file",
    desc = "Copy a file to S3",
  })

  vim.api.nvim_create_user_command("S3CopyDir", function(opts)
    local path = opts.args ~= "" and opts.args or nil
    M.copy_dir(path)
  end, {
    nargs = "?",
    complete = "file",
    desc = "Copy a directory to S3",
  })
end

return M
