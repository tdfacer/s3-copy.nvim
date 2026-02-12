-- Autoload guard for s3-copy.nvim
if vim.g.loaded_s3_copy then
  return
end
vim.g.loaded_s3_copy = true

require("s3_copy.commands").setup()
