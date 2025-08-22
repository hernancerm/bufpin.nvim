# Bufpin

Manually track a list of bufs and visualize the list in the tabline.

## Features

- Display the pinned bufs in the tabline.
- Expose an API to track the pinned bufs.
- Out of the box key mappings to manage pinned bufs.
- Mouse support to left-click to edit buf and middle-click to remove buf.
- Auto-hide the tabline when there are no pinned bufs.
- Store the pinned bufs in session.
- Show file type icons.

Suggested complementary plugins:


| Plugin                                                          | Benefit                                        | Integrate via install and...                                 |
|-----------------------------------------------------------------|------------------------------------------------|--------------------------------------------------------------|
| [vim-obsession](https://github.com/tpope/vim-obsession)         | Persist the pinned bufs among Neovim sessions. | Set in your init.lua:<br>`vim.opt.ssop:append("globals")`    |
| [mini.bufremove](https://github.com/echasnovski/mini.bufremove) | Preserve window layout when removing bufs.     | Set in your config of Bufpin:<br>`use_mini_bufremove = true` |
| [vim-lastplace](https://github.com/farmergreg/vim-lastplace)    | Remember the cursor location in visited bufs.  | -                                                            |
| [mini.icons](https://github.com/echasnovski/mini.icons)         | Display file type icon next to buf name.       | Use a [Nerd Font](https://www.nerdfonts.com/).               |

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
  use_mini_bufremove = false,
  icons_style = "monochrome",
  remove_with = "delete"
})
```

Default key mappings:

```lua
local o = { silent = true }
local kset = vim.keymap.set
kset("n",  "<Leader>p",  ":cal v:lua.Bufpin.toggle()<CR>", o)
kset("n",  "<Leader>w",  ":cal v:lua.Bufpin.remove()<CR>", o)
kset("n",  "<Up>",       ":cal v:lua.Bufpin.edit_left()<CR>", o)
kset("n",  "<Down>",     ":cal v:lua.Bufpin.edit_right()<CR>", o)
kset("n",  "<Left>",     ":cal v:lua.Bufpin.move_to_left()<CR>", o)
kset("n",  "<Right>",    ":cal v:lua.Bufpin.move_to_right()<CR>", o)
kset("n",  "<F1>",       ":cal v:lua.Bufpin.edit_by_index(1)<CR>", o)
kset("n",  "<F2>",       ":cal v:lua.Bufpin.edit_by_index(2)<CR>", o)
kset("n",  "<F3>",       ":cal v:lua.Bufpin.edit_by_index(3)<CR>", o)
kset("n",  "<F4>",       ":cal v:lua.Bufpin.edit_by_index(4)<CR>", o)
```

## Documentation

Please refer to the help file: [bufpin.txt](./doc/bufpin.txt).

## Similar experience in IdeaVim

In IntelliJ a similar experience can be had to the one offered by this plugin. It's not the same,
but it's close enough, at least for me, to feel uniform. Configure IntelliJ like this:

- IntelliJ: In Settings set the tab limit to 1: "Editor > Editor Tabs > Tab limit: 1".
- [IdeaVim](https://github.com/JetBrains/ideavim): In `~/.ideavimrc` add this to match the default
  key maps of this plugin:

```text
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
