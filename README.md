# Bufpin

Manually track a list of bufs and visualize it in the tabline.

<div align=center>
  <img src="media/demo.gif" alt="bufpin.nvim demo" />
</div>
<!--
nvim \
  README.md \
  Makefile \
  scripts/minidoc.lua \
  scripts/testdocs_init.lua \
  lua/bufpin/hsluv.lua \
  lua/bufpin/init.lua
:SatelliteDisable
:%bd|e#|lua Bufpin.pin(vim.fn.bufnr())
Recording width/height: 215x14 (https://getkap.co/)
On .editorconfig `max_line_length`s to: 0
-->

## Features

- Display the pinned bufs in the tabline.
- Out of the box key mappings to manage pinned bufs.
- Sensible default colors for Bufpin's highlight groups.
- Mouse support to left-click to edit buf and middle-click to remove buf.
- Store the pinned bufs in session (`:mksession`) if `vim.opt.ssop:append("globals")`.
- Auto-hide the tabline when there are no pinned bufs.
- Expose an API to track the pinned bufs.
- Show file type icons.

Suggested complementary plugins:

- [mini.icons](https://github.com/echasnovski/mini.icons):
  Display file type icon next to buf name. Use a [Nerd Font](https://www.nerdfonts.com/).
- [mini.bufremove](https://github.com/echasnovski/mini.bufremove):
  Preserve window layout when removing bufs.
- [vim-lastplace](https://github.com/farmergreg/vim-lastplace):
  Remember the cursor location in visited bufs.

## Out of scope

- Be a fully-fledged tabline plugin like
  [bufferline.nvim](https://github.com/akinsho/bufferline.nvim).

## Requirements

- Neovim >= 0.11.0

## Installation

Use your favorite package manager. For example, [Lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "hernancerm/bufpin.nvim",
  -- IMPORTANT: If you have installed mini.icons or mini.bufremove, set their
  -- priority to something greater than 0. The idea is that those plugins
  -- should be loaded _before_ bufpin.nvim.
  priority = 0,
  opts = {}
},
```

The function `require("bufpin").setup()` needs to be called. Lazy.nvim does this using the snippet
above.

## Default config

```lua
local bufpin = require("bufpin")
bufpin.setup()
```

Is equivalent to:

```lua
local bufpin = require("bufpin")
bufpin.setup({
  auto_hide_tabline = true,
  set_default_keymaps = true,
  exclude = function(_) end,
  use_mini_bufremove = true,
  icons_style = "monochrome_selected",
  ghost_buf_enabled = true,
  remove_with = "delete",
  logging = {
    enabled = false,
    level = vim.log.levels.INFO,
  },
})
```

Default key mappings:

```lua
local kset = vim.keymap.set
local opts = { silent = true }
kset("n",  "<Leader>p",  ":cal v:lua.Bufpin.toggle()<CR>",          opts)
kset("n",  "<Leader>w",  ":cal v:lua.Bufpin.remove()<CR>",          opts)
kset("n",  "<Up>",       ":cal v:lua.Bufpin.edit_left()<CR>",       opts)
kset("n",  "<Down>",     ":cal v:lua.Bufpin.edit_right()<CR>",      opts)
kset("n",  "<Left>",     ":cal v:lua.Bufpin.move_to_left()<CR>",    opts)
kset("n",  "<Right>",    ":cal v:lua.Bufpin.move_to_right()<CR>",   opts)
kset("n",  "<F1>",       ":cal v:lua.Bufpin.edit_by_index(1)<CR>",  opts)
kset("n",  "<F2>",       ":cal v:lua.Bufpin.edit_by_index(2)<CR>",  opts)
kset("n",  "<F3>",       ":cal v:lua.Bufpin.edit_by_index(3)<CR>",  opts)
kset("n",  "<F4>",       ":cal v:lua.Bufpin.edit_by_index(4)<CR>",  opts)
```

## Documentation

Please refer to the help file: [bufpin.txt](./doc/bufpin.txt).

## JetBrains IDEs

To get a similar experience in JetBrains IDEs follow these instructions:

- IDE: In Settings set the tab limit to 1: "Editor > Editor Tabs > Tab limit: 1".
- [IdeaVim](https://github.com/JetBrains/ideavim): In `~/.ideavimrc` add this to match the default
  key maps of this plugin:

```vim
nmap      <Space>p  <Action>(PinActiveEditorTab)
nmap      <Space>w  <Action>(CloseContent)
nmap      <Up>      <Action>(PreviousTab)
nmap      <Down>    <Action>(NextTab)
nnoremap  <Left>    :tabmove -1<CR>
nnoremap  <Right>   :tabmove +1<CR>
nmap      <F1>      <Action>(GoToTab1)
nmap      <F2>      <Action>(GoToTab2)
nmap      <F3>      <Action>(GoToTab3)
nmap      <F4>      <Action>(GoToTab4)
```

## Inspiration

- [Harpoon](https://github.com/ThePrimeagen/harpoon)
- [IntelliJ IDEA](https://www.jetbrains.com/idea/)
- [IdeaVim](https://github.com/JetBrains/ideavim)

## Contributing

I welcome issues requesting any behavior change. However, please do not submit a PR unless it's for
a trivial fix.

## License

[MIT](./LICENSE)
