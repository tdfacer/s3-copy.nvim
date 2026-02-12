# s3-copy.nvim

Copy a visual selection to S3 using the AWS CLI.

## Installation

### lazy.nvim

```lua
{
  "trevor/s3-copy.nvim",
  config = function()
    require("s3_copy").setup({
      bucket = "my-bucket",
      key_prefix = "/s3-copy.nvim/",
    })
  end,
}
```

### packer.nvim

```lua
use {
  "trevor/s3-copy.nvim",
  config = function()
    require("s3_copy").setup({
      bucket = "my-bucket",
      key_prefix = "/s3-copy.nvim/",
    })
  end,
}
```

## Usage

1) Select text in visual mode
2) Run `:S3CopySelection`
3) Confirm or edit the bucket and key prompts

The default S3 key is built from the current file path (relative to the CWD) plus a timestamp, with the configured prefix.

### Suggested Keymaps

```lua
vim.keymap.set("v", "<leader>sy", "<cmd>S3CopySelection<cr>", { desc = "S3 copy selection" })
vim.keymap.set("n", "<leader>sf", "<cmd>S3CopyFile<cr>", { desc = "S3 copy file" })
vim.keymap.set("n", "<leader>sD", "<cmd>S3CopyDir<cr>", { desc = "S3 copy directory" })
vim.keymap.set("n", "<leader>sr", "<cmd>S3ReadFile<cr>", { desc = "S3 read file" })
```

## Commands

| Command | Description |
|---------|-------------|
| `:S3CopySelection` | Copy the current visual selection to S3 |
| `:S3CopyFile [path]` | Copy a file to S3 (defaults to current buffer) |
| `:S3CopyDir [path]` | Copy a directory to S3 (defaults to buffer directory or CWD) |
| `:S3ReadFile` | Select and read an S3 object into a scratch buffer |

## Configuration

```lua
require("s3_copy").setup({
  bucket = "my-bucket",
  read_bucket = "my-bucket",
  key_prefix = "/s3-copy.nvim/",
})
```

`read_bucket` defaults to `bucket` if unset.

## UI

Prompts use `vim.ui.input`, so you can hook in a nicer UI with plugins like `dressing.nvim`.

## Requirements

- `aws` CLI available on your PATH

## License

MIT
