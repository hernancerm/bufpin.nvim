# Pin

A [Harpoon](https://github.com/ThePrimeagen/harpoon)-inspired buffer manager for
[IdeaVim](https://github.com/JetBrains/ideavim) users.

This plugin does not work for IntelliJ. The goal is to mimic in Neovim an experience that can be had
with IdeaVim.

## Pitch

### Problem

For work I use IntelliJ with IdeaVim. I find myself frequenting a small set of files. As I explore
the codebase, each file I jump to creates a tab. Quickly there are too many tabs open and then I ask
myself, where is that important file that I was looking at? "It always gets lost in the tabs", I
think. So I close the tabs I don't care about. Aha! There is the file. Then I keep exploring the
codebase, and I face the same problem, and so I proceed by applying the same solution. This
janitorial exercise gets annoying since it's pervasive when exploring code.

In my non-work time I use Neovim. It feels like there I suffer from the opposite problem. This does
not need much explanation, that's why Harpoon exists.

### Solution - IntelliJ

I want a solution that works uniformly both in IntelliJ and Neovim. I also want to see the small set
of files instead of memorizing them. I think tabs are a good way to show these files.

My solution in IntelliJ is setting the tab limit to 1:

```text
Settings > Editor > Editor Tabs > Tab limit: 1
```

And having key mappings like these for IdeaVim:

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

### Solution - Neovim

This plugin, which provides the IntelliJ behavior as described above.

## Features

- Store pinned buffers in session, for sessions either managed manually or through a plugin.

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

The function `require("pin").setup()` needs to be called. Lazy.nvim does this automatically using
the snippet above.

## Default config

```lua
local pin = require("pin")
pin.setup()
```

Is equivalent to:

```lua
```

Default key mappings:

```lua
vim.keymap.set("n", "<Leader>p", pin.toggle, opts())
vim.keymap.set("n", "<Leader>w", pin.wipeout, opts())
vim.keymap.set("n", "<Up>", pin.edit_left, opts())
vim.keymap.set("n", "<Down>", pin.edit_right, opts())
vim.keymap.set("n", "<Left>", pin.move_left, opts())
vim.keymap.set("n", "<Right>", pin.move_right, opts())
vim.keymap.set("n", "<F1>", function() pin.edit_by_index(1) end, opts())
vim.keymap.set("n", "<F2>", function() pin.edit_by_index(2) end, opts())
vim.keymap.set("n", "<F3>", function() pin.edit_by_index(3) end, opts())
vim.keymap.set("n", "<F4>", function() pin.edit_by_index(4) end, opts())
```

## Documentation

Please refer to the help file: [pin.txt](./doc/pin.txt).

## Inspiration

- [Harpoon](https://github.com/ThePrimeagen/harpoon)
- [IntelliJ IDEA](https://www.jetbrains.com/idea/)

## Contributing

I welcome issues requesting any behavior change. However, please do not submit a PR unless it's for
a trivial fix.

## License

[MIT](./LICENSE)
