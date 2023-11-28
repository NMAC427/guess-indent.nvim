# `:GuessIndent`

![MIT License](https://img.shields.io/github/license/NMAC427/guess-indent.nvim)
![Tests](https://github.com/NMAC427/guess-indent.nvim/actions/workflows/ci.yml/badge.svg)

Blazing fast indentation style detection for Neovim written in Lua.
The goal of this plugin is to automatically detect the indentation style used
in a buffer and updating the buffer options accordingly.
This mimics the "*Guess Indentation Settings From Buffer*" function built into
Sublime Text.

<img src="https://user-images.githubusercontent.com/9914734/154780206-c60eda09-175d-4ee8-81be-2aea1fcaadf4.gif" style="width: 100%">

## How it works

Whenever you open a new buffer, guess-indent looks at the first few hundred
lines and uses them to determine how the buffer should be indented.
It then automatically updates the buffer options so that they match the 
opened file.

## Installation

Install using your favorite package manager and then call the following setup
function somewhere in your config:

```lua
require('guess-indent').setup {}
```

If you are using [packer.nvim](https://github.com/wbthomason/packer.nvim), you
can install and set up guess-indent simultaneously:

```lua
-- using packer.nvim
use {
  'nmac427/guess-indent.nvim',
  config = function() require('guess-indent').setup {} end,
}
```

## Usage

By default, guess-indent automatically runs whenever you open a new buffer.
You can also run it manually using the `:GuessIndent` command.

## Configuration

The plugin provides the following configuration options:

```lua
-- This is the default configuration
require('guess-indent').setup {
  auto_cmd = true,  -- Set to false to disable automatic execution
  override_editorconfig = false, -- Set to true to override settings set by .editorconfig
  filetype_exclude = {  -- A list of filetypes for which the auto command gets disabled
    "netrw",
    "tutor",
  },
  buftype_exclude = {  -- A list of buffer types for which the auto command gets disabled
    "help",
    "nofile",
    "terminal",
    "prompt",
  },
  on_tab_options = { -- A table of vim options when tabs are detected 
    ["expandtab"] = false,
  },
  on_space_options = { -- A table of vim options when spaces are detected 
    ["expandtab"] = true,
    ["tabstop"] = "detected", -- If the option value is 'detected', The value is set to the automatically detected indent size.
    ["softtabstop"] = "detected",
    ["shiftwidth"] = "detected",
  },
}
```

Normally it should not be necessary to disable the automatic execution of
guess-indent, because it usually takes less than a millisecond to run,
even for large files.

## Alternatives

- [`indent-o-matic`](https://github.com/Darazaki/indent-o-matic) - Blazingly
    fast, written in lua, based on a very simple algorithm.
    [Comparison](https://github.com/Darazaki/indent-o-matic/issues/12)
- [`vim-sleuth`](https://github.com/tpope/vim-sleuth) - Very smart but slower
    heuristic, compatible with Vim.

## Licence

This project is licensed under the terms of the MIT license.
For more detail check out the [LICENSE](./LICENSE) file.
