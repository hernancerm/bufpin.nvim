# Bufpin

Pin buffers for quick navigation.

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

## Problem

From https://github.com/ThePrimeagen/harpoon/tree/harpoon2:

> You're working on a codebase. medium, large, tiny, whatever. You find
> yourself frequenting a small set of files and you are tired of using a fuzzy
> finder, :bnext & :bprev are getting too repetitive, alternate file doesn't
> quite cut it, etc etc.

## Solution

Pin buffers and allow navigating to them via keymaps. The pinned bufs are
drawn in the 'tabline'. Visually, this looks like tabs in a modern text
editor, but the distinction is that the bufs are all **manually tracked**.

## Features

- Display the pinned bufs and the vim tabpages in the tabline.
- Display a "ghost buf" in the tabline, i.e., the last visited non-pinned pin-able buf.
- Store the pinned bufs in session (`:mksession`) if `vim.opt.ssop:append("globals")`.
- Mouse support to left-click to edit buf and middle-click to remove buf (also works on vim tabpages).
- Mouse support to re-order the pinned bufs and the vim tabpages by dragging them.
- Auto-hide the tabline when there are no pinned bufs.
- Mouse support to double-left-click a buf in the tabline to pin it.
- Git integration showing git status per tabline buf.
- Expose an API to track the pinned bufs.
- Show file type icons.

Suggested complementary plugins:

- [mini.bufremove](https://github.com/echasnovski/mini.bufremove):
  Preserve window layout when removing bufs.
- [vim-lastplace](https://github.com/farmergreg/vim-lastplace):
  Remember the cursor location in visited bufs.
- [mini.icons](https://github.com/echasnovski/mini.icons):
  Display file type icons. Use a [Nerd Font](https://www.nerdfonts.com/).

## Requirements

- Neovim >= 0.12.0
- Git (optional)

## Installation

Install with your favorite package manager. For example, using Neovim's builtin package manager,
[vim.pack](https://neovim.io/doc/user/pack/#vim.pack):

```lua
vim.pack.add({
  "https://github.com/hernancerm/bufpin.nvim",
})

local opts = { silent = true }
vim.keymap.set("n",  "<Up>",       ":lua Bufpin.edit_left()<CR>",       opts)
vim.keymap.set("n",  "<Down>",     ":lua Bufpin.edit_right()<CR>",      opts)
vim.keymap.set("n",  "<Left>",     ":lua Bufpin.move_to_left()<CR>",    opts)
vim.keymap.set("n",  "<Right>",    ":lua Bufpin.move_to_right()<CR>",   opts)
vim.keymap.set("n",  "<Leader>1",  ":lua Bufpin.edit_by_index(1)<CR>",  opts)
vim.keymap.set("n",  "<Leader>2",  ":lua Bufpin.edit_by_index(2)<CR>",  opts)
vim.keymap.set("n",  "<Leader>3",  ":lua Bufpin.edit_by_index(3)<CR>",  opts)
vim.keymap.set("n",  "<Leader>4",  ":lua Bufpin.edit_by_index(4)<CR>",  opts)
vim.keymap.set("n",  "<Leader>5",  ":lua Bufpin.edit_by_index(5)<CR>",  opts)
vim.keymap.set("n",  "<Leader>6",  ":lua Bufpin.edit_by_index(6)<CR>",  opts)
vim.keymap.set("n",  "<Leader>7",  ":lua Bufpin.edit_by_index(7)<CR>",  opts)
vim.keymap.set("n",  "<Leader>8",  ":lua Bufpin.edit_by_index(8)<CR>",  opts)
vim.keymap.set("n",  "<Leader>9",  ":lua Bufpin.edit_by_index(9)<CR>",  opts)
vim.keymap.set("n",  "<Leader>0",  ":lua Bufpin.edit_by_index(0)<CR>",  opts)
```

Some things to notice:

- `require("bufpin").setup()` does **not** need to be called. You may call it to configure the plugin.
- The plugin does **not** create keymaps, you need to define them as shown above.

## Default config

```lua
require("bufpin").setup({
  auto_hide_tabline = true,
  exclude = function(_) end,
  use_mini_bufremove = true,
  icons_style = "monochrome_selected",
  sticky_remove_enabled = true,
  mouse_drag_reorder = true,
  ghost_buf_enabled = true,
  remove_with = "delete",
  git_status_enabled = true,
  git_status_symbols = {
    added = "&",
    modified = "~",
    conflict = "!",
  },
})
```

## Documentation

Please refer to the help file: [bufpin.txt](./doc/bufpin.txt).

## Recipes

Add quickfix bufs to the list of pinned bufs:

```lua
local bufpin = require("bufpin")
vim.keymap.set("n", "<Leader>P", function()
  local bufnrs = vim
    .iter(vim.fn.getqflist())
    :map(function(item)
      return item.bufnr
    end)
    :filter(function(bufnr)
      return bufnr > 0
    end)
    :totable()
  if #bufnrs == 0 then
    vim.notify("No bufs in the quickfix list.", vim.log.levels.WARN)
    return
  end
  bufpin.pin(bufnrs)
end, opts)
```

Remove all tabline bufs except current:

```lua
local bufpin = require("bufpin")
vim.keymap.set("n", "<Leader>W", function()
  if #bufpin.get_pinned_bufs() == 0 then
    return
  end
  local cur_buf = vim.fn.bufnr()
  bufpin.remove(vim.iter(bufpin.get_tabline_bufs())
    :filter(function(bufnr)
      return bufnr ~= cur_buf
    end)
    :totable())
  if cur_buf == bufpin.get_ghost_buf() then
    bufpin.pin()
  end
end, opts)
```

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
nmap      <Space>1  <Action>(GoToTab1)
nmap      <Space>2  <Action>(GoToTab2)
nmap      <Space>3  <Action>(GoToTab3)
nmap      <Space>4  <Action>(GoToTab4)
nmap      <Space>5  <Action>(GoToTab5)
nmap      <Space>6  <Action>(GoToTab6)
nmap      <Space>7  <Action>(GoToTab7)
nmap      <Space>8  <Action>(GoToTab8)
nmap      <Space>9  <Action>(GoToTab9)
nmap      <Space>0  <Action>(GoToLastTab)
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
