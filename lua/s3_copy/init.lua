local M = {}

local config = require("s3_copy.config")

function M.setup(opts)
  config.setup(opts)
end

M.copy_selection = function()
  require("s3_copy.commands").copy_selection()
end

return M
