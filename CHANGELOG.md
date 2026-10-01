# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Vim tabpages are drawn in the tabline, to the right of the bufs.
- Re-order pinned bufs and vim tabpages by mouse-dragging them. Opt `mouse_drag_reorder`.
- Double-left-click a buf in the tabline to pin it.
- On overflow, the tabline keeps the selected buf in view and draws the count of hidden bufs on
  each edge.
- Git status symbols next to dirty bufs. Opts `git_status_enabled` and `git_status_symbols`.
- Opt `sticky_remove_enabled`: on `remove()`, focus the last visited pinned buf or ghost buf.
- Opt `tabpage_scope_enabled`, to give each vim tabpage its own pinned bufs and ghost buf.
- `get_tabline_bufs()` and `get_ghost_buf()`.
- `pin()`, `unpin()` and `remove()` accept a list of bufs. `pin()` asks for confirmation above 5
  bufs, see its opt `ask_above`.
- `edit_by_index(0)` edits the last buf of the tabline.
- Highlight group `BufpinTabLine`, for unselected pinned bufs.

### Changed

- Calling `setup()` is no longer required. Call it only to configure the plugin.
- Requires Neovim 0.12.
- The index of `edit_by_index()` is into `get_tabline_bufs()`, so the ghost buf is reachable.
- `get_pinned_bufs()` returns a copy instead of the actual list.
- `remove()` asks for confirmation on a modified buf, instead of not removing it.
- Highlight defaults are taken from `TabLine`, `TabLineFill` and `TabLineSel`.
- The plugins load order no longer matters.
- Faster startup.

### Removed

- Config key `set_default_keymaps`, and with it the default keymaps. Set your own keymaps.
- Config key `logging`, and with it the log file.
- Highlight group `BufpinGhostTabLineFill`.

### Fixed

- Pinned buf losing the focus on `vim.lsp.buf.hover()`.
- Error on `:colorscheme vim`.
- `%` in a file name drawn wrong, e.g. `100%.txt`.
- Error on editing a buf from a `'winfixbuf'` win. It is now a no-op.
- Some pinned bufs cannot be removed, e.g. bufs pinned from the quickfix list.
- Files with the same name are not differentiated when one is the ghost buf.
- Ghost buf drawn when no buf is pinned, given `auto_hide_tabline = false`.

## [0.2.2] - 2025-09-08

### Changed

- Faster startup.

### Fixed

- Highlight defaults not set for the default colorscheme.

## [0.2.1] - 2025-09-07

### Fixed

- `mini.bufremove` not recognized as installed.

## [0.2.0] - 2025-09-07

### Added

- Ghost buf: the last visited non-pinned buf, drawn last in the tabline. Opt `ghost_buf_enabled`.
- File type icons, with `mini.icons`. Opt `icons_style`.
- Files with the same name are differentiated by their parent dir.
- `move_to_left()` and `move_to_right()` accept a buf.
- Highlight groups `BufpinTabLineSel`, `BufpinTabLineFill`, `BufpinGhostTabLineSel` and
  `BufpinGhostTabLineFill`, with defaults that fit the colorscheme.
- Opt `logging`, disabled by default.

### Changed

- Opt `use_mini_bufremove` is true by default.

### Fixed

- Wrong buf selected in the tabline when the `blink.cmp` menu opens.

## [0.1.0] - 2025-05-18

Initial release.

### Added

- Pinned bufs drawn in the tabline. The tabline is hidden when no buf is pinned, opt
  `auto_hide_tabline`.
- Functions `pin()`, `unpin()`, `toggle()`, `remove()`, `edit_by_index()`, `get_pinned_bufs()` and
  `refresh_tabline()`.
- Edit the pinned buf to the left or right with `edit_left()` and `edit_right()`, wrapping around
  at the edges. Re-order with `move_to_left()` and `move_to_right()`.
- Default keymaps, opt `set_default_keymaps`.
- Exclude bufs from pinning with opt `exclude`.
- Buf removal by delete or wipeout, opt `remove_with`. Optionally via `mini.bufremove`, opt
  `use_mini_bufremove`.
- Left-click a buf in the tabline to edit it. Middle-click to remove it.
- Pinned bufs persist in sessions.

[Unreleased]: https://github.com/hernancerm/bufpin.nvim/compare/0.2.2...HEAD
[0.2.2]: https://github.com/hernancerm/bufpin.nvim/compare/0.2.1...0.2.2
[0.2.1]: https://github.com/hernancerm/bufpin.nvim/compare/0.2.0...0.2.1
[0.2.0]: https://github.com/hernancerm/bufpin.nvim/compare/0.1.0...0.2.0
[0.1.0]: https://github.com/hernancerm/bufpin.nvim/releases/tag/0.1.0
