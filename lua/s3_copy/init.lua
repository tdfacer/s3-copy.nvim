local M = {}

local config = require("s3_copy.config")

function M.setup(opts)
  config.setup(opts)
end

M.copy_selection = function()
  require("s3_copy.commands").copy_selection()
end

M.copy_file = function(path)
  require("s3_copy.commands").copy_file(path)
end

M.copy_dir = function(path)
  require("s3_copy.commands").copy_dir(path)
end

return M
