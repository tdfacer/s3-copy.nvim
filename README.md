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

### Suggested Keymap

```lua
vim.keymap.set("v", "<leader>sy", "<cmd>S3CopySelection<cr>", { desc = "S3 copy selection" })
```

## Commands

| Command | Description |
|---------|-------------|
| `:S3CopySelection` | Copy the current visual selection to S3 |

## Configuration

```lua
require("s3_copy").setup({
  bucket = "my-bucket",
  key_prefix = "/s3-copy.nvim/",
})
```

## Requirements

- `aws` CLI available on your PATH

## License

MIT
