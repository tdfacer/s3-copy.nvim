local M = {}

M.defaults = {
  bucket = nil,
  read_bucket = nil,
  key_prefix = "/s3-copy.nvim/",
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
