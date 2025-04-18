# Pin

A [Harpoon](https://github.com/ThePrimeagen/harpoon)-inspired buffer manager for
[IdeaVim](https://github.com/JetBrains/ideavim) users.

Demo showing the managed (pinned) bufs in the tabline (with the config `{ pin_marker = "[P]" }`):

[![asciicast](https://asciinema.org/a/716176.svg)](https://asciinema.org/a/716176)

Please note: This is a plugin for Neovim, not for IntelliJ. Pin does not change any behavior in
IntelliJ or IdeaVim. The goal of this plugin is to mimic in Neovim an experience that can be had in
IntelliJ with IdeaVim.

## Pitch

### Problem

For work I use IntelliJ with IdeaVim. I find myself frequenting a small list of files. As I explore
the codebase, each file I jump to creates a tab. Quickly there are too many tabs open and then I ask
myself, where is that important file that I was looking at? "It always gets lost in the tabs", I
think. So I close the tabs I don't care about. Aha! There is the file. Then I keep exploring the
codebase, and I face the same problem, and so I proceed by applying the same solution. Facing this
confusion many times a day gets annoying. Have you ever noticed this janitorial exercise and be
bothered by it?

### Solution

I want a solution that works uniformly both in IntelliJ and Neovim. I want to always _see_ the small
list of files instead of memorizing them. My solution is to display the list of files as tabs. In
IntelliJ that is as pinned tabs and in Neovim it's through a tabline provided by this plugin.

For IntelliJ, set the tab limit to 1:

```text
Settings > Editor > Editor Tabs > Tab limit: 1
```

And set these key mappings for IdeaVim:

```text
nmap <Space>p <Action>(PinActiveEditorTab)
nmap <Space>w <Action>(CloseContent)
nmap <Up> <Action>(PreviousTab)
nmap <Down> <Action>(NextTab)
nnoremap <Left> :tabmove -1<CR>
nnoremap <Right> :tabmove +1<CR>
let tab_number = 1
while tab_number <= 4
  execute "nmap <F" . tab_number . "> <Action>(GoToTab" . tab_number . ")"
  let tab_number = tab_number + 1
endwhile
```

## Features

- Display the pinned bufs in the tabline.
- Expose an API to track the pinned bufs.
- Out of the box key mappings to manage pinned bufs.
- Store the pinned bufs in session, for sessions either managed manually or through a plugin.
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
  -- In Nerd Fonts is "nf-md-pin".
  -- - <https://www.nerdfonts.com/cheat-sheet>
  -- - <https://www.compart.com/en/unicode/U+F0403>.
  pin_marker = "󰐃",
  auto_hide_tabline = true,
  set_default_keymaps = true,
})
```

Default key mappings:

```lua
local opts = { silent = true }
vim.keymap.set("n", "<Leader>p", pin.toggle, opts)
vim.keymap.set("n", "<Leader>w", pin.wipeout, opts)
vim.keymap.set("n", "<Up>", pin.edit_left, opts)
vim.keymap.set("n", "<Down>", pin.edit_right, opts)
vim.keymap.set("n", "<Left>", pin.move_left, opts)
vim.keymap.set("n", "<Right>", pin.move_right, opts)
vim.keymap.set("n", "<F1>", function()
  pin.edit_by_index(1)
end, opts)
vim.keymap.set("n", "<F2>", function()
  pin.edit_by_index(2)
end, opts)
vim.keymap.set("n", "<F3>", function()
  pin.edit_by_index(3)
end, opts)
vim.keymap.set("n", "<F4>", function()
  pin.edit_by_index(4)
end, opts)
```

## Documentation

Please refer to the help file: [pin.txt](./doc/pin.txt).

## Inspiration

- [Harpoon](https://github.com/ThePrimeagen/harpoon)
- [IntelliJ IDEA](https://www.jetbrains.com/idea/)
- [IdeaVim](https://github.com/JetBrains/ideavim)

## Contributing

I welcome issues requesting any behavior change. However, please do not submit a PR unless it's for
a trivial fix.

## License

[MIT](./LICENSE)
