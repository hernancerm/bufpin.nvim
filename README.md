# Pin

A [Harpoon](https://github.com/ThePrimeagen/harpoon)-inspired buffer manager for
[IdeaVim](https://github.com/JetBrains/ideavim) users.

<!--
Demo showing the managed (pinned) bufs in the tabline (`[P]` indicates that the buf is pinned):

[![asciicast](https://asciinema.org/a/716260.svg)](https://asciinema.org/a/716260)
-->

**This is a plugin for Neovim, not for IntelliJ. This plugin allows Neovim to mimic a particular
behavior in IntelliJ.**

## Problem

In both IntelliJ and Neovim, there is no way to keep a list of files which does not get polluted
during codebase navigation. In IntelliJ, a tab is opened per visited file. In Neovim, a buffer is
created per visited file. In both IntelliJ and Neovim I have to do a periodic janitorial exercise to
keep in sight the files I care about, either closing tabs (IntelliJ) or deleting buffers (Neovim).
Have you ever noticed this yourself and be bothered by it?

I want a solution that is mostly uniformly in both IntelliJ and Neovim.

## Solution

Solution idea:

- How do I track the files I care about?
  - IntelliJ and Neovim: Through "pinning" files via a dedicated key map.
- How do I keep in sight the list of files?
  - IntelliJ and Neovim: Display the files in tabs as it's standard in IntelliJ.
- What happens when navigating among non pinned files?
  - IntelliJ: A maximum of 1 non-pinned file is shown.
  - Neovim: The tabline only ever shows pinned files.

How do I get this experience in IntelliJ?:

- IntelliJ: In Settings set the tab limit to 1: "Editor > Editor Tabs > Tab limit: 1".
- IdeaVim: In `~/.ideavimrc` add this to match the default key maps of this plugin:

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

## Features

- Display the pinned bufs in the tabline.
- Expose an API to track the pinned bufs.
- Out of the box key mappings to manage pinned bufs.
- Store the pinned bufs in sessions both managed manually or through a plugin (e.g.,
  [vim-obsession](https://github.com/tpope/vim-obsession)).
- Opt-in integration with [mini.bufremove](https://github.com/echasnovski/mini.bufremove) to
  preserve window layout.
- Auto-hide the tabline when there are no pinned bufs.

## Out of scope

- Be a fully-fledged tabline plugin like
  [bufferline.nvim](https://github.com/akinsho/bufferline.nvim).

## Requirements

- Neovim >= 0.11.0

## Installation

Use your favorite package manager. For example, [Lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "hernancerm/pin.nvim",
  opts = {}
},
```

The function `require("pin").setup()` needs to be called. Lazy.nvim does this using the snippet
above.

## Default config

```lua
local pin = require("pin")
pin.setup()
```

Is equivalent to:

```lua
local pin = require("pin")
pin.setup({
  auto_hide_tabline = true,
  set_default_keymaps = true,
  exclude = function(_) end,
  use_mini_bufremove = false,
  remove_with = "delete",
})
```

Default key mappings:

```lua
local o = { silent = true }
local kset = vim.keymap.set
kset("n",  "<Leader>p",  ":cal v:lua.Pin.toggle()<CR>", o)
kset("n",  "<Leader>w",  ":cal v:lua.Pin.remove()<CR>", o)
kset("n",  "<Up>",       ":cal v:lua.Pin.edit_left()<CR>", o)
kset("n",  "<Down>",     ":cal v:lua.Pin.edit_right()<CR>", o)
kset("n",  "<Left>",     ":cal v:lua.Pin.move_to_left()<CR>", o)
kset("n",  "<Right>",    ":cal v:lua.Pin.move_to_right()<CR>", o)
kset("n",  "<F1>",       ":cal v:lua.Pin.edit_by_index(1)<CR>", o)
kset("n",  "<F2>",       ":cal v:lua.Pin.edit_by_index(2)<CR>", o)
kset("n",  "<F3>",       ":cal v:lua.Pin.edit_by_index(3)<CR>", o)
kset("n",  "<F4>",       ":cal v:lua.Pin.edit_by_index(4)<CR>", o)
```

## Documentation

Please refer to the help file: [pin.txt](./doc/pin.txt).

## Suggested complementary plugins

These plugins are completely independent from pin.nvim, but can enhance the experience with
pin.nvim:

- [farmergreg/vim-lastplace](https://github.com/farmergreg/vim-lastplace): Remember the cursor
  location when navigating among bufs.
  - How to integrate with pin.nvim?:
    - Just install the plugin.
- [echasnovski/mini.bufremove](https://github.com/echasnovski/mini.bufremove): Preserve window
  layout when removing bufs. This is useful when, for example, having nvim-tree open and removing a
  buf, so nvim-tree does not take the full screen and instead the alt buf is shown in the window
  where the buf was removed.
  - How to integrate with pin.nvim?:
    - Install the plugin and set `use_mini_bufremove = true` in pin.nvim's config.
- [tpope/vim-obsession](https://github.com/tpope/vim-obsession): Persist among sessions the pinned
  bufs.
  - How to integrate with pin.nvim?:
    - Install the plugin and add `vim.opt.sessionoptions:append("globals")` in your `init.lua`.

## Inspiration

- [Harpoon](https://github.com/ThePrimeagen/harpoon)
- [IntelliJ IDEA](https://www.jetbrains.com/idea/)
- [IdeaVim](https://github.com/JetBrains/ideavim)

## Contributing

I welcome issues requesting any behavior change. However, please do not submit a PR unless it's for
a trivial fix.

## License

[MIT](./LICENSE)
