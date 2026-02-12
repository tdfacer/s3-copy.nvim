local M = {}

local function normalize_bucket(bucket)
  if not bucket or bucket == "" then
    return ""
  end
  bucket = bucket:gsub("^s3://", "")
  bucket = bucket:gsub("/+$", "")
  return bucket
end

local function normalize_key_prefix(prefix)
  if not prefix or prefix == "" then
    return ""
  end
  prefix = prefix:gsub("^/+", "")
  if prefix ~= "" and not prefix:match("/$") then
    prefix = prefix .. "/"
  end
  return prefix
end

local function normalize_key(key)
  if not key or key == "" then
    return ""
  end
  key = key:gsub("^/+", "")
  return key
end

function M.default_filename()
  local bufname = vim.api.nvim_buf_get_name(0)
  local path

  if bufname ~= "" then
    path = vim.fn.fnamemodify(bufname, ":.")
  else
    path = "selection"
  end

  path = path:gsub("^/+", "")
  local timestamp = os.date("%Y%m%d-%H%M%S")
  return string.format("%s-%s", path, timestamp)
end

function M.build_s3_target(bucket, key)
  bucket = normalize_bucket(bucket)
  key = normalize_key(key)

  if bucket == "" or key == "" then
    return nil
  end

  return string.format("s3://%s/%s", bucket, key)
end

function M.build_default_key(prefix, filename)
  local safe_prefix = normalize_key_prefix(prefix)
  local safe_name = normalize_key(filename)
  if safe_name == "" then
    safe_name = "selection"
  end
  return safe_prefix .. safe_name
end

return M
