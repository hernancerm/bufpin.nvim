local h = {}

---@class PinnedBuf
---@field bufnr integer
---@field basename string
---@field differentiator string?
---@field selected boolean

---@param config_use_mini_bufremove boolean
---@return boolean
function h.should_use_mini_bufremove(config_use_mini_bufremove)
  return config_use_mini_bufremove and h.has_mini_bufremove()
end

--- For session persistence. Store state in `vim.g.BufpinState`. Deserialize in
--- the autocmd event `SessionLoadPost.` In `pinned_bufs`, full file names are
--- serialized. Note: Neovim has no `SessionWritePre` event:
--- <https://github.com/neovim/neovim/issues/22814>.
---@param config_ghost_buf_enabled boolean
function h.serialize_state(config_ghost_buf_enabled)
  local state = {
    pinned_buf_names = vim
      .iter(h.state.pinned_bufnrs)
      :filter(function(bufnr)
        return vim.fn.bufexists(bufnr) == 1
      end)
      :map(function(bufnr)
        return vim.api.nvim_buf_get_name(bufnr)
      end)
      :totable(),
  }
  if
    config_ghost_buf_enabled
    and h.state.ghost_bufnr ~= nil
    and vim.fn.bufexists(h.state.ghost_bufnr) == 1
  then
    state.ghost_buf_name = vim.api.nvim_buf_get_name(h.state.ghost_bufnr)
  end
  vim.g.BufpinState = vim.json.encode(state)
end

--- Escape text for literal display in the tabline. A `%` in a file name would
--- otherwise be parsed as the start of a statusline item, see 'statusline'.
---@param text string
---@return string
function h.escape_tabline_text(text)
  return (text:gsub("%%", "%%%%"))
end

---@param pinned_buf PinnedBuf
---@param config_icons_style string
---@return string
function h.build_tabline_pinned_buf(pinned_buf, config_icons_style)
  local basename = pinned_buf.basename
  if pinned_buf.differentiator ~= nil then
    basename = pinned_buf.differentiator .. "/" .. basename
  end
  if pinned_buf.selected then
    return "%"
      .. pinned_buf.bufnr
      .. "@bufpin#_on_click_buffer@"
      .. "%#"
      .. h.const.HL_BUFPIN_TAB_LINE_SEL
      .. "#  "
      .. h.get_icon_string_for_tabline_buf(
        basename,
        true,
        false,
        config_icons_style
      )
      .. h.escape_tabline_text(basename)
      .. "  %*"
      .. "%X"
  else
    return "%"
      .. pinned_buf.bufnr
      .. "@bufpin#_on_click_buffer@"
      .. "%#"
      .. h.const.HL_BUFPIN_TAB_LINE
      .. "#  "
      .. h.get_icon_string_for_tabline_buf(
        basename,
        false,
        false,
        config_icons_style
      )
      .. h.escape_tabline_text(basename)
      .. "  %*"
      .. "%X"
  end
end

---@param config_icons_style string
---@return string
function h.build_tabline_ghost_buf(config_icons_style)
  local ghost_buf = h.state.ghost_bufnr
  if ghost_buf == nil then
    return ""
  end
  local ghost_buf_is_selected = ghost_buf == vim.fn.bufnr()
  local hl = h.const.HL_BUFPIN_GHOST_TAB_LINE
  if ghost_buf_is_selected then
    hl = h.const.HL_BUFPIN_GHOST_TAB_LINE_SEL
  end
  local basename = vim.fs.basename(vim.api.nvim_buf_get_name(ghost_buf))
  return "%"
    .. ghost_buf
    .. "@bufpin#_on_click_buffer@"
    .. "%#"
    .. hl
    .. "#  "
    .. h.get_icon_string_for_tabline_buf(
      basename,
      ghost_buf_is_selected,
      true,
      config_icons_style
    )
    .. h.escape_tabline_text(basename)
    .. "  %*"
    .. "%X"
end

---@param buf_name string
---@param buf_is_selected boolean
---@param is_ghost_buf boolean
---@param config_icons_style string
function h.get_icon_string_for_tabline_buf(
  buf_name,
  buf_is_selected,
  is_ghost_buf,
  config_icons_style
)
  local has_mini_icons = h.has_mini_icons()
  if not has_mini_icons or config_icons_style == "hidden" then
    return ""
  end
  local bufpin_icon_hl = nil
  local icon, icon_hl = nil, nil
  if has_mini_icons then
    ---@diagnostic disable-next-line: undefined-global
    icon, icon_hl = MiniIcons.get("file", buf_name)
    bufpin_icon_hl = "Bufpin"
      .. (buf_is_selected and "Sel" or "Fill")
      .. (is_ghost_buf and "Ghost" or "")
      .. icon_hl
    if
      vim.tbl_contains({
        "color",
        "monochrome_selected",
      }, config_icons_style)
    then
      if h.state.hl_cache[bufpin_icon_hl] == nil then
        local hl = {
          bg = h.get_icon_hi_bg(buf_is_selected, is_ghost_buf),
          fg = h.get_hl(icon_hl).fg,
        }
        vim.api.nvim_set_hl(0, bufpin_icon_hl, hl)
        h.state.hl_cache[bufpin_icon_hl] = hl
      end
    end
  end
  local icon_string = ""
  local hl_buf_selected = h.const.HL_BUFPIN_TAB_LINE_SEL
  if is_ghost_buf then
    hl_buf_selected = h.const.HL_BUFPIN_GHOST_TAB_LINE_SEL
  end
  local hl_buf = h.const.HL_BUFPIN_TAB_LINE
  if is_ghost_buf then
    hl_buf = h.const.HL_BUFPIN_GHOST_TAB_LINE
  end
  if buf_is_selected then
    if has_mini_icons then
      if config_icons_style == "color" then
        icon_string = "%#"
          .. bufpin_icon_hl
          .. "#"
          .. icon
          .. "%*%#"
          .. hl_buf_selected
          .. "# "
      elseif
        config_icons_style == "monochrome"
        or config_icons_style == "monochrome_selected"
      then
        icon_string = icon .. " "
      end
    end
  else
    if has_mini_icons then
      if
        config_icons_style == "color"
        or config_icons_style == "monochrome_selected"
      then
        icon_string = "%#"
          .. bufpin_icon_hl
          .. "#"
          .. icon
          .. "%*%#"
          .. hl_buf
          .. "# "
      elseif config_icons_style == "monochrome" then
        icon_string = icon .. " "
      end
    end
  end
  return icon_string
end

---@param buf_is_selected boolean
---@param is_ghost_buf boolean
---@return integer
function h.get_icon_hi_bg(buf_is_selected, is_ghost_buf)
  if buf_is_selected and not is_ghost_buf then
    return h.get_hl(h.const.HL_BUFPIN_TAB_LINE_SEL).bg
  end
  if not buf_is_selected and not is_ghost_buf then
    return h.get_hl(h.const.HL_BUFPIN_TAB_LINE).bg
  end
  if buf_is_selected and is_ghost_buf then
    return h.get_hl(h.const.HL_BUFPIN_GHOST_TAB_LINE_SEL).bg
  end
  if not buf_is_selected and is_ghost_buf then
    return h.get_hl(h.const.HL_BUFPIN_GHOST_TAB_LINE).bg
  end
  error("Invalid state: Highlight group not found")
end

--- Get highlight group. Follows links.
--- Returns empty table for non-defined highlight groups.
---@param hl_name string
---@return table
function h.get_hl(hl_name)
  local hl = vim.api.nvim_get_hl(0, {
    name = hl_name,
    create = false,
  })
  while type(hl.link) == "string" do
    hl = vim.api.nvim_get_hl(0, {
      name = hl.link,
      create = false,
    })
  end
  return hl
end

--- A drawable tabline item (a pinned buf or the ghost buf).
---@class TablineItem
---@field render string The 'tabline' string, including highlight/click escapes.
---@field width integer The display width of the visible content.
---@field selected boolean Whether this item is the current buf.

--- The display width of a 'tabline' string: the width of its visible content,
--- ignoring the statusline items used in this plugin, i.e., `%#hl#`, `%N@fn@`,
--- `%*`, `%X` and `%=`. The escaped percent (`%%`) counts as one column.
---@param tabline string
---@return integer
function h.get_display_width(tabline)
  -- Resolve `%%` first so an escaped `%` cannot be parsed as an item start.
  -- Use a placeholder so the resulting `%` is not re-parsed either.
  local visible = tabline
    :gsub("%%%%", "\1")
    :gsub("%%#[^#]*#", "")
    :gsub("%%%d+@[^@]*@", "")
    :gsub("%%[*X=]", "")
    :gsub("\1", "%%")
  return vim.fn.strdisplaywidth(visible)
end

--- Build the drawable items for the tabline: the pinned bufs followed by the
--- ghost buf (when applicable). Each item carries its display width so the
--- tabline can be windowed to fit the available space.
---@param pinned_bufs PinnedBuf[]
---@param config_icons_style string
---@param config_ghost_buf_enabled boolean
---@return TablineItem[]
function h.build_tabline_items(
  pinned_bufs,
  config_icons_style,
  config_ghost_buf_enabled
)
  local pinned_bufs_by_bufnr = {}
  for _, pinned_buf in ipairs(pinned_bufs) do
    pinned_bufs_by_bufnr[pinned_buf.bufnr] = pinned_buf
  end
  local items = {}
  for _, bufnr in ipairs(h.tracked_bufs(config_ghost_buf_enabled)) do
    local pinned_buf = pinned_bufs_by_bufnr[bufnr]
    local render, selected
    if pinned_buf ~= nil then
      render = h.build_tabline_pinned_buf(pinned_buf, config_icons_style)
      selected = pinned_buf.selected
    else
      render = h.build_tabline_ghost_buf(config_icons_style)
      selected = bufnr == vim.fn.bufnr()
    end
    table.insert(items, {
      render = render,
      width = h.get_display_width(render),
      selected = selected,
    })
  end
  return items
end

--- A truncation indicator drawn at an edge of the tabline to signal how many
--- items are hidden in that direction. The arrow points outwards, i.e., `<3` on
--- the left edge and `3>` on the right edge.
---@param side "left"|"right"
---@param hidden integer
---@return string
function h.build_tabline_indicator(side, hidden)
  local text = side == "left" and "<" .. hidden or hidden .. ">"
  return "%#" .. h.const.HL_BUFPIN_TAB_LINE_FILL .. "#" .. text
end

--- The display width of a truncation indicator, e.g., 2 for `<3`.
---@param hidden integer
---@return integer
function h.get_tabline_indicator_width(hidden)
  return 1 + #tostring(hidden)
end

--- Given the leftmost visible item `first`, find the rightmost item that still
--- fits within `available` columns, reserving space for the edge indicators.
---@param items TablineItem[]
---@param available integer
---@param first integer
---@return integer last The index of the rightmost visible item.
function h.fit_last_visible_item(items, available, first)
  local n = #items
  -- Reserve columns for the left indicator when not starting at the first item.
  local budget = available
  if first > 1 then
    budget = budget - h.get_tabline_indicator_width(first - 1)
  end
  local acc = 0
  local last = first - 1
  for i = first, n do
    acc = acc + items[i].width
    -- Reserve columns for the right indicator when items remain hidden past `i`.
    local reserved = 0
    if i < n then
      reserved = h.get_tabline_indicator_width(n - i)
    end
    if acc + reserved <= budget then
      last = i
    else
      break
    end
  end
  -- Always draw at least the leftmost item, even if it overflows.
  return math.max(last, first)
end

--- Concatenate the tabline items, windowing them to fit `available` columns.
--- The selected item is kept visible: when it crosses an edge of the viewport it
--- is anchored to that edge (leftmost when scrolling left, rightmost when
--- scrolling right), matching the direction of |bufpin.edit_left()| and
--- |bufpin.edit_right()|. Edge indicators (`<3`, `3>`) signal how many items are
--- hidden in that direction.
--- Records the screen column range of each drawn item in
--- `h.state.tabline_item_cols`.
---@param items TablineItem[]
---@param available integer
---@return string
function h.build_tabline_window(items, available)
  local n = #items
  h.state.tabline_item_cols = {}
  if n == 0 then
    return ""
  end
  local total = 0
  for _, item in ipairs(items) do
    total = total + item.width
  end
  local first, last = 1, n
  if total > available then
    local selected = nil
    for i, item in ipairs(items) do
      if item.selected then
        selected = i
        break
      end
    end
    -- Start from the previously drawn viewport for stability across refreshes.
    first = math.min(math.max(h.state.tabline_first_visible or 1, 1), n)
    -- Anchor the selected item to the left edge when it scrolled off the left.
    if selected ~= nil and selected < first then
      first = selected
    end
    last = h.fit_last_visible_item(items, available, first)
    -- Anchor the selected item to the right edge when it scrolled off the right.
    if selected ~= nil then
      while selected > last and first < n do
        first = first + 1
        last = h.fit_last_visible_item(items, available, first)
      end
    end
  end
  h.state.tabline_first_visible = first
  local parts = {}
  local col = 1
  if first > 1 then
    table.insert(parts, h.build_tabline_indicator("left", first - 1))
    col = col + h.get_tabline_indicator_width(first - 1)
  end
  for i = first, last do
    table.insert(parts, items[i].render)
    -- Record where each item is drawn, for mouse support.
    table.insert(h.state.tabline_item_cols, {
      index = i,
      first_col = col,
      last_col = col + items[i].width - 1,
    })
    col = col + items[i].width
  end
  if last < n then
    table.insert(parts, h.build_tabline_indicator("right", n - last))
  end
  return table.concat(parts)
end

--- The entry of `drawn_cols` covering the given tabline screen column, or nil
--- when nothing is drawn there.
---@param drawn_cols { index:integer, first_col:integer, last_col:integer }[]
---@param col integer
---@return { index:integer, first_col:integer, last_col:integer }?
function h.get_item_at_col(drawn_cols, col)
  for _, item_cols in ipairs(drawn_cols) do
    if col >= item_cols.first_col and col <= item_cols.last_col then
      return item_cols
    end
  end
  return nil
end

--- Start a tabline drag gesture, for |bufpin.config.mouse_drag_reorder|. Called
--- on left mouse press on a tabline item, from the click handlers in
--- `autoload/bufpin.vim`. The <LeftDrag> and <LeftRelease> keymaps exist only
--- for the duration of the drag gesture and are buffer-local, so mouse behavior
--- everywhere else (e.g., dragging a visual selection) is unaffected.
---@param kind "buf"|"tabpage" What the pressed tabline item is.
---@param handle integer Bufnr of the pressed buf or the pressed tabpage.
function h.on_tabline_press(kind, handle)
  if not require("bufpin").config.mouse_drag_reorder then
    return
  end
  -- Track the pressed item and pick the <LeftDrag> handler for its kind.
  local on_drag = h.on_tabline_buf_drag
  if kind == "buf" then
    h.state.drag_bufnr = handle
  else
    h.state.drag_tabpage = handle
    on_drag = h.on_tabline_tabpage_drag
  end
  -- The click handler already switched to the pressed buf/tabpage, so the
  -- gesture's keymaps go on the buf which is current for the whole gesture.
  local bufnr = vim.api.nvim_get_current_buf()
  vim.keymap.set("n", "<LeftDrag>", on_drag, { buffer = bufnr })
  vim.keymap.set("n", "<LeftRelease>", function()
    h.state.drag_bufnr = nil
    h.state.drag_tabpage = nil
    pcall(vim.keymap.del, "n", "<LeftDrag>", { buffer = bufnr })
    pcall(vim.keymap.del, "n", "<LeftRelease>", { buffer = bufnr })
  end, { buffer = bufnr })
end

--- <LeftDrag> handler during a buf drag. Re-orders the pinned bufs,
--- Firefox-style: the dragged buf takes the place of the hovered buf.
function h.on_tabline_buf_drag()
  local mousepos = vim.fn.getmousepos()
  if mousepos.screenrow ~= 1 then
    return
  end
  local drag_index = h.table_find_index(h.state.pinned_bufnrs, h.state.drag_bufnr)
  local target = h.get_item_at_col(h.state.tabline_item_cols, mousepos.screencol)
  if
    -- The ghost buf can neither be dragged nor be a drop target.
    drag_index == nil
    or target == nil
    or target.index > #h.state.pinned_bufnrs
    or target.index == drag_index
  then
    return
  end
  -- Re-order only once the mouse crosses the midpoint of the hovered buf, in
  -- the drag direction. Otherwise, when the swapped bufs have different widths,
  -- the re-order oscillates: after the swap the mouse hovers the displaced buf,
  -- immediately triggering the reverse swap. Crossing the midpoint guarantees
  -- that after the swap the mouse is not past the displaced buf's midpoint.
  local target_mid = (target.first_col + target.last_col) / 2
  if target.index > drag_index and mousepos.screencol <= target_mid then
    return
  end
  if target.index < drag_index and mousepos.screencol >= target_mid then
    return
  end
  table.remove(h.state.pinned_bufnrs, drag_index)
  table.insert(h.state.pinned_bufnrs, target.index, h.state.drag_bufnr)
  require("bufpin").refresh_tabline()
end

--- <LeftDrag> handler during a vim tabpage drag. Re-orders the vim tabpages:
--- the dragged tabpage takes the place of the hovered tabpage. Unlike the
--- pinned bufs, the vim tabpages are labeled by their number, so they all have
--- the same width. Hence, no midpoint check is needed to prevent the re-order
--- from oscillating, so the drag can re-order as soon as the mouse moves onto
--- the hovered tabpage.
function h.on_tabline_tabpage_drag()
  local mousepos = vim.fn.getmousepos()
  if mousepos.screenrow ~= 1 then
    return
  end
  -- A tabpage's index is its position in the list of tabpages.
  local drag_index =
    h.table_find_index(vim.api.nvim_list_tabpages(), h.state.drag_tabpage)
  local target =
    h.get_item_at_col(h.state.tabline_tabpage_cols, mousepos.screencol)
  if drag_index == nil or target == nil or target.index == drag_index then
    return
  end
  -- `:tabmove {count}` moves the current tabpage to after tabpage {count}, with
  -- {count} being counted before the move; zero makes it the first one. The
  -- dragged tabpage is the current one: the click handler switched to it on
  -- press, and moving it around keeps it current.
  local count = target.index
  if target.index < drag_index then
    count = target.index - 1
  end
  vim.cmd("tabmove " .. count)
  require("bufpin").refresh_tabline()
end

---@param pinned_bufs PinnedBuf[]
---@param config_icons_style string
---@return string
function h.build_tabline(
  pinned_bufs,
  config_icons_style,
  config_ghost_buf_enabled
)
  local items = h.build_tabline_items(
    pinned_bufs,
    config_icons_style,
    config_ghost_buf_enabled
  )
  local vim_tabpages = h.build_tabline_vim_tabpages()
  -- The tabline spans the whole editor width. Reserve room for the vim tabpages
  -- section, which is right-aligned via `%=`.
  local available = vim.o.columns - h.get_display_width(vim_tabpages)
  return h.build_tabline_window(items, available)
    .. "%#"
    .. h.const.HL_BUFPIN_TAB_LINE_FILL
    .. "#"
    .. vim_tabpages
end

--- The vim tabpages section of the tabline, right-aligned via `%=`. Records the
--- screen column range of each drawn tabpage in `h.state.tabline_tabpage_cols`.
---@return string
function h.build_tabline_vim_tabpages()
  h.state.tabline_tabpage_cols = {}
  local vim_tabpages = "%=  "
  local tabpages = vim.api.nvim_list_tabpages()
  -- Do not show vim tabpages when there is only one.
  if #tabpages == 1 then
    return ""
  end
  -- Columns are recorded relative to the section, i.e., the first tabpage is
  -- drawn right after the leading padding. They are shifted after the loop.
  local col = h.get_display_width(vim_tabpages) + 1
  local current_tabpage = vim.api.nvim_get_current_tabpage()
  for i, tabpage in ipairs(tabpages) do
    local hl = h.const.HL_BUFPIN_TAB_LINE
    if current_tabpage == tabpage then
      hl = h.const.HL_BUFPIN_TAB_LINE_SEL
    end
    local label = " " .. i .. " "
    vim_tabpages = vim_tabpages
      .. "%"
      .. tabpage
      .. "@bufpin#_on_click_tabpage@"
      .. "%#"
      .. hl
      .. "#"
      .. label
      .. "%*%X"
    -- Record where each tabpage is drawn, for mouse support.
    table.insert(h.state.tabline_tabpage_cols, {
      index = i,
      first_col = col,
      last_col = col + #label - 1,
    })
    col = col + #label
  end
  -- The section is drawn flush right, so it ends at the last screen column.
  local offset = vim.o.columns - h.get_display_width(vim_tabpages)
  for _, tabpage_cols in ipairs(h.state.tabline_tabpage_cols) do
    tabpage_cols.first_col = tabpage_cols.first_col + offset
    tabpage_cols.last_col = tabpage_cols.last_col + offset
  end
  return vim_tabpages
end

---@param config_ghost_buf_enabled boolean
---@return boolean
function h.should_include_ghost_buf(config_ghost_buf_enabled)
  if h.state.ghost_bufnr == nil or not config_ghost_buf_enabled then
    return false
  end
  -- Do not include ghost buf when there are no pinned bufs.
  -- This is relevant when using vim tabpages only.
  return #h.state.pinned_bufnrs > 0
end

function h.set_hl_defaults()
  -- Don't override existing hl definitions.
  local attribs_base = { default = true }
  local attribs_ghost =
    vim.tbl_deep_extend("force", attribs_base, { italic = true })
  local hl_normal = h.get_hl("Normal")
  local hl_tab_line = vim.tbl_deep_extend("keep", h.get_hl("TabLine"), hl_normal)
  vim.api.nvim_set_hl(
    0,
    h.const.HL_BUFPIN_TAB_LINE,
    vim.tbl_deep_extend("force", hl_tab_line, attribs_base)
  )
  vim.api.nvim_set_hl(
    0,
    h.const.HL_BUFPIN_GHOST_TAB_LINE,
    vim.tbl_deep_extend("force", hl_tab_line, attribs_ghost)
  )
  local hl_tab_line_sel =
    vim.tbl_deep_extend("keep", h.get_hl("TabLineSel"), hl_normal)
  vim.api.nvim_set_hl(
    0,
    h.const.HL_BUFPIN_TAB_LINE_SEL,
    vim.tbl_deep_extend("force", hl_tab_line_sel, attribs_base)
  )
  vim.api.nvim_set_hl(
    0,
    h.const.HL_BUFPIN_GHOST_TAB_LINE_SEL,
    vim.tbl_deep_extend("force", hl_tab_line_sel, attribs_ghost)
  )
  local hl_tab_line_fill =
    vim.tbl_deep_extend("keep", h.get_hl("TabLineFill"), hl_normal)
  vim.api.nvim_set_hl(
    0,
    h.const.HL_BUFPIN_TAB_LINE_FILL,
    vim.tbl_deep_extend("force", hl_tab_line_fill, attribs_base)
  )
end

--- Find the index of a value in a list-like table.
---@param tbl table Numerically indexed table (list).
---@param target_value any The value being searched in `tbl`.
---@return integer? Index or nil if the item was not found.
function h.table_find_index(tbl, target_value)
  local index = nil
  for i, tbl_value in ipairs(tbl) do
    if target_value == tbl_value then
      index = i
      break
    end
  end
  return index
end

---@param bufnr integer
---@return boolean
function h.is_plugin_buf(bufnr)
  local no_name_filetypes = { nil, "" }
  local matched_filetype, _ = vim.filetype.match({ buf = bufnr })
  return matched_filetype == nil
    and not vim.bo.buflisted
    and not vim.tbl_contains(no_name_filetypes, vim.bo[bufnr].filetype)
end

---@param win_id integer
---@return boolean
function h.is_floating_win(win_id)
  -- See |api-floatwin| to learn how to check whether a win is floating.
  return vim.api.nvim_win_get_config(win_id).relative ~= ""
end

function h.prune_invalid_pinned_bufs_from_state()
  h.state.pinned_bufnrs = vim
    .iter(h.state.pinned_bufnrs)
    :filter(function(bufnr)
      return vim.fn.bufexists(bufnr) == 1
    end)
    :totable()
end

function h.prune_invalid_ghost_buf_from_state()
  if
    vim.tbl_contains(h.state.pinned_bufnrs, h.state.ghost_bufnr)
    or vim.fn.bufexists(h.state.ghost_bufnr) == 0
    -- For some reason uknown to me, help files need special handling.
    or (
      h.state.ghost_bufnr ~= nil
      and vim.bo[h.state.ghost_bufnr].buftype == "help"
    )
  then
    h.state.ghost_bufnr = nil
  end
end

---@param bufnr integer
function h.pin_by_bufnr(bufnr)
  local bufnr_index = h.table_find_index(h.state.pinned_bufnrs, bufnr)
  if bufnr_index == nil then
    table.insert(h.state.pinned_bufnrs, bufnr)
  end
end

---@param bufnr integer
function h.unpin_by_bufnr(bufnr)
  local bufnr_index = h.table_find_index(h.state.pinned_bufnrs, bufnr)
  if bufnr_index ~= nil then
    table.remove(h.state.pinned_bufnrs, bufnr_index)
  end
end

--- Show the tabline only when there is a pinned buf to show.
function h.show_tabline()
  if #h.state.pinned_bufnrs > 0 or #vim.api.nvim_list_tabpages() > 1 then
    vim.o.showtabline = 2
  else
    vim.o.showtabline = 0
  end
end

function h.print_user_error(message)
  vim.api.nvim_echo({ { message, "Error" } }, true, {})
end

-- TODO: Consider ghost buf to differentiate repeating basenames in tabline.

---@return integer[]
function h.get_bufnrs_with_repeating_basename()
  local basenames_count = {}
  local bufs_with_repeating_basename = {}
  for _, pinned_buf in ipairs(h.state.pinned_bufnrs) do
    local basename = vim.fs.basename(vim.api.nvim_buf_get_name(pinned_buf))
    if basenames_count[basename] == nil then
      basenames_count[basename] = 1
    else
      basenames_count[basename] = basenames_count[basename] + 1
    end
  end
  for _, pinned_buf in ipairs(h.state.pinned_bufnrs) do
    local basename = vim.fs.basename(vim.api.nvim_buf_get_name(pinned_buf))
    if basenames_count[basename] > 1 then
      table.insert(bufs_with_repeating_basename, pinned_buf)
    end
  end
  return bufs_with_repeating_basename
end

---@return PinnedBuf[]
function h.normalize_pinned_bufs()
  local pinned_bufnrs = {}
  local current_bufnr = vim.fn.bufnr()
  local bufnrs_with_repeating_basename = h.get_bufnrs_with_repeating_basename()
  for _, bufnr in ipairs(h.state.pinned_bufnrs) do
    local full_filename = vim.api.nvim_buf_get_name(bufnr)
    if vim.tbl_contains(bufnrs_with_repeating_basename, bufnr) then
      -- Set differentiator when >1 pinned bufs have the same basename. Use always
      -- the parent directory to attempt to differentiate. This strategy ignores
      -- the rare case of different parent dirs having the same name.
      local parent_dir = vim.fn.fnamemodify(full_filename, ":h:t")
      if vim.fn.fnamemodify(full_filename, ":h") == vim.uv.cwd() then
        parent_dir = "."
      end
      table.insert(pinned_bufnrs, {
        bufnr = bufnr,
        basename = vim.fs.basename(full_filename),
        selected = current_bufnr == bufnr,
        differentiator = parent_dir,
      })
    else
      table.insert(pinned_bufnrs, {
        bufnr = bufnr,
        basename = vim.fs.basename(full_filename),
        selected = current_bufnr == bufnr,
      })
    end
  end
  return pinned_bufnrs
end

--- Bufs tracked by bufpin in the order they are drawn in the tabline.
---@param config_ghost_buf_enabled boolean
---@return integer[]
function h.tracked_bufs(config_ghost_buf_enabled)
  local bufnrs = vim.deepcopy(h.state.pinned_bufnrs)
  if h.should_include_ghost_buf(config_ghost_buf_enabled) then
    table.insert(bufnrs, h.state.ghost_bufnr)
  end
  return bufnrs
end

--- Get the buf to focus after removing `bufnr`: the tracked buf visited most
--- recently, or else the neighbor of `bufnr` in the tabline, right before left.
--- The neighbor is the fallback for when no candidate holds a visit.
---@param bufnr integer Buf being removed.
---@param config_ghost_buf_enabled boolean
---@return integer?
function h.sticky_buf(bufnr, config_ghost_buf_enabled)
  -- Require 'buflisted' so the jump never lands on a buf the user removed from
  -- the buf list, e.g. via `:noautocmd bdelete`, which fires no BufDelete.
  local tracked_bufnrs = vim.tbl_filter(function(tracked_bufnr)
    return vim.fn.buflisted(tracked_bufnr) == 1
  end, h.tracked_bufs(config_ghost_buf_enabled))
  local latest_order = 0
  local latest_bufnr = nil
  for _, candidate_bufnr in ipairs(tracked_bufnrs) do
    -- Unvisited candidates hold order 0, so they never win.
    local order = h.state.visit_order[candidate_bufnr] or 0
    if candidate_bufnr ~= bufnr and order > latest_order then
      latest_order = order
      latest_bufnr = candidate_bufnr
    end
  end
  if latest_bufnr ~= nil then
    return latest_bufnr
  end
  local index = h.table_find_index(tracked_bufnrs, bufnr)
  if index == nil then
    return nil
  end
  return tracked_bufnrs[index + 1] or tracked_bufnrs[index - 1]
end

--- Whether the buf is tracked by bufpin, i.e., pinned or the ghost buf.
---@param bufnr integer?
---@return boolean
function h.is_tracked_buf(bufnr)
  return bufnr ~= nil
    and (
      vim.tbl_contains(h.state.pinned_bufnrs, bufnr)
      or bufnr == h.state.ghost_bufnr
    )
end

---@param bufnr integer
---@param config_exclude function
---@return boolean
function h.should_exclude_from_pin(bufnr, config_exclude)
  return config_exclude(bufnr)
    or vim.api.nvim_buf_get_name(bufnr) == ""
    or vim.bo[bufnr].buftype == "quickfix"
    or vim.bo[bufnr].buftype == "nofile"
    or vim.bo[bufnr].buftype == "help"
    or h.is_plugin_buf(bufnr)
    or h.is_floating_win(0)
end

h.state = {
  hl_cache = {},
  pinned_bufnrs = {},
  -- Approach for managing the state of ghost_bufnr: Set in an autocmd, then set
  -- to nil (or rearely to another buf) on a case-by-case basis per API function.
  ghost_bufnr = nil,
  -- Visit order per buf, as `bufnr -> visit_count` at the time of the visit. The
  -- bufnr with the highest `visit_count` is the most recently visited buf.
  visit_order = {},
  visit_count = 0,
  -- Index of the leftmost item drawn in the tabline. Persisted across refreshes
  -- so the horizontal scroll position is stable when the tabline overflows.
  tabline_first_visible = 1,
  -- Screen column ranges ({ index, first_col, last_col }) of the items drawn in
  -- the tabline, set on each refresh. Used for mouse support.
  tabline_item_cols = {},
  -- As `tabline_item_cols`, for the vim tabpages drawn in the tabline.
  tabline_tabpage_cols = {},
  -- Buf being mouse-dragged in the tabline, when `mouse_drag_reorder` is
  -- enabled. Set on left mouse press on a tabline buf, unset on release.
  drag_bufnr = nil,
  -- As `drag_bufnr`, for a vim tabpage being mouse-dragged in the tabline.
  drag_tabpage = nil,
}

h.const = {
  HL_BUFPIN_TAB_LINE = "BufpinTabLine",
  HL_BUFPIN_GHOST_TAB_LINE = "BufpinGhostTabLine",
  HL_BUFPIN_TAB_LINE_SEL = "BufpinTabLineSel",
  HL_BUFPIN_GHOST_TAB_LINE_SEL = "BufpinGhostTabLineSel",
  HL_BUFPIN_TAB_LINE_FILL = "BufpinTabLineFill",
}

--- Returns true when mini.icons is installed:
--- <https://github.com/nvim-mini/mini.icons>.
---@return boolean
function h.has_mini_icons()
  return package.loaded["mini.icons"] ~= nil
end

--- Returns true when mini.bufremove is installed:
--- <https://github.com/nvim-mini/mini.bufremove>.
---@return boolean
function h.has_mini_bufremove()
  return package.loaded["mini.bufremove"] ~= nil
end

--- Returns true when runr.nvim is installed:
--- <https://github.com/hernancerm/runr.nvim>.
---@return boolean
function h.has_runr()
  return package.loaded["runr"] ~= nil
end

return h
