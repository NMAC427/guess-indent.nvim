# guess-indent.nvim

Blazing fast indentation style detection for Neovim written in Lua.
The goal of this plugin is to automatically detect the indentation style used
in a buffer and updating the buffer options accordingly.
This mimics the "Guess Indentation Settings From Buffer" function of Sublime
Text.

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
require('guess-indent').setup {
  auto_cmd = true | false,  -- Set to false to disable automatic execution
}
```

Normally it should not be necessary to disable the automatic execution of
guess-indent, because it usually takes less than a millisecond to run,
even for large files.

## Inspiration

This plugin was inspired by
[DubFriend/guess-indent](https://github.com/DubFriend/guess-indent)
and
[Darazaki/indent-o-matic](https://github.com/Darazaki/indent-o-matic)
.

## Licence

```
MIT License

Copyright (c) 2022 Nicolas Camenisch

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
