local M = {}

local config = require("s3_copy.config")
local util = require("s3_copy.util")

local function normalize_bucket(bucket)
  if not bucket or bucket == "" then
    return ""
  end
  bucket = bucket:gsub("^s3://", "")
  bucket = bucket:gsub("/+$", "")
  return bucket
end

local function normalize_prefix(prefix)
  if not prefix or prefix == "" then
    return ""
  end
  prefix = prefix:gsub("^/+", "")
  return prefix
end

local function build_bucket_uri(bucket, prefix)
  local safe_bucket = normalize_bucket(bucket)
  local safe_prefix = normalize_prefix(prefix)

  if safe_bucket == "" then
    return nil
  end

  if safe_prefix == "" then
    return string.format("s3://%s", safe_bucket)
  end

  return string.format("s3://%s/%s", safe_bucket, safe_prefix)
end

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

local function aws_base_args()
  return { "env", "AWS_PAGER=", "AWS_CLI_AUTO_PROMPT=off", "aws", "--no-cli-pager" }
end

local function list_s3_objects(bucket, prefix)
  local uri = build_bucket_uri(bucket, prefix)
  if not uri then
    vim.notify("Bucket is required", vim.log.levels.ERROR)
    return nil
  end

  local output = vim.fn.system(vim.list_extend(aws_base_args(), { "s3", "ls", "--recursive", uri }))
  if vim.v.shell_error ~= 0 then
    local message = vim.trim(output)
    if message == "" then
      message = "Failed to list S3 objects"
    else
      message = "Failed to list S3 objects: " .. message
    end
    vim.notify(message, vim.log.levels.ERROR)
    return nil
  end

  local keys = {}
  for _, line in ipairs(vim.split(output, "\n", { plain = true, trimempty = true })) do
    local key = line:match("^%S+%s+%S+%s+%d+%s+(.+)$")
    if key and key ~= "" then
      table.insert(keys, key)
    end
  end

  if #keys == 0 then
    vim.notify("No objects found", vim.log.levels.WARN)
    return nil
  end

  return keys
end

local function open_scratch_buffer(name, content)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "swapfile", false)
  vim.api.nvim_buf_set_option(buf, "modifiable", true)

  if name and name ~= "" then
    vim.api.nvim_buf_set_name(buf, name)
  end

  local lines = vim.split(content or "", "\n", { plain = true, trimempty = false })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  local filetype = nil
  if vim.filetype and vim.filetype.match and name then
    filetype = vim.filetype.match({ filename = name })
  end
  if filetype then
    vim.api.nvim_buf_set_option(buf, "filetype", filetype)
  end

  vim.api.nvim_set_current_buf(buf)
end

local function list_files_for_picker()
  local cwd = vim.fn.getcwd()
  local paths = vim.fn.globpath(cwd, "**/*", false, true)
  local files = {}

  for _, path in ipairs(paths) do
    local stat = vim.loop.fs_stat(path)
    if stat and stat.type == "file" then
      table.insert(files, path)
    end
  end

  return files
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
    local ok = run_aws_cp(vim.list_extend(aws_base_args(), { "s3", "cp", "--only-show-errors", "-", target }), selection)
    if ok then
      vim.notify("Copied selection to " .. target, vim.log.levels.INFO)
    end
  end)
end

function M.read_file()
  if not ensure_aws_cli() then
    return
  end

  local default_bucket = config.options.read_bucket or config.options.bucket
  prompt_input("S3 bucket: ", default_bucket, function(bucket)
    if bucket == nil then
      return
    end

    if bucket == "" then
      vim.notify("Bucket is required", vim.log.levels.ERROR)
      return
    end

    local default_prefix = config.options.key_prefix
    prompt_input("Prefix (optional): ", default_prefix or "", function(prefix)
      if prefix == nil then
        return
      end

      local keys = list_s3_objects(bucket, prefix)
      if not keys then
        return
      end

      vim.ui.select(keys, { prompt = "Select S3 object:" }, function(choice)
        if not choice then
          return
        end

        local target = util.build_s3_target(bucket, choice)
        if not target then
          vim.notify("Invalid bucket or key", vim.log.levels.ERROR)
          return
        end

        local output = vim.fn.system(vim.list_extend(aws_base_args(), { "s3", "cp", "--only-show-errors", target, "-" }))
        if vim.v.shell_error ~= 0 then
          local message = vim.trim(output)
          if message == "" then
            message = "S3 read failed"
          else
            message = "S3 read failed: " .. message
          end
          vim.notify(message, vim.log.levels.ERROR)
          return
        end

        open_scratch_buffer(target, output)
      end)
    end)
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
      local ok = run_aws_cp(vim.list_extend(aws_base_args(), { "s3", "cp", "--only-show-errors", resolved_path, target }))
      if ok then
        vim.notify("Copied file to " .. target, vim.log.levels.INFO)
      end
    end)
  end

  if path and path ~= "" then
    proceed(normalize_path(path))
  else
    local files = list_files_for_picker()
    if #files > 0 then
      vim.ui.select(files, {
        prompt = "Select file to copy:",
        format_item = function(item)
          return vim.fn.fnamemodify(item, ":.")
        end,
      }, function(choice)
        if not choice then
          return
        end
        proceed(choice)
      end)
    else
      prompt_input("File path: ", default_path, function(value)
        if value == nil then
          return
        end
        proceed(normalize_path(value))
      end)
    end
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
      local ok = run_aws_cp(vim.list_extend(aws_base_args(), {
        "s3",
        "cp",
        "--only-show-errors",
        "--recursive",
        resolved_path,
        target,
      }))
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

  vim.api.nvim_create_user_command("S3ReadFile", function()
    M.read_file()
  end, {
    desc = "Read an S3 object into a scratch buffer",
  })
end

return M
