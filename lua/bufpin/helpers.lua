local h = {}

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
      .. "@BufpinTlOnClickBuf@"
      .. "%#"
      .. h.const.HL_BUFPIN_TAB_LINE_SEL
      .. "#  "
      .. h.get_icon_string_for_tabline_buf(
        basename,
        true,
        false,
        config_icons_style
      )
      .. basename
      .. "  %*"
      .. "%X"
  else
    return "%"
      .. pinned_buf.bufnr
      .. "@BufpinTlOnClickBuf@"
      .. "%#"
      .. h.const.HL_BUFPIN_TAB_LINE_FILL
      .. "#  "
      .. h.get_icon_string_for_tabline_buf(
        basename,
        false,
        false,
        config_icons_style
      )
      .. basename
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
  local hl = h.const.HL_BUFPIN_GHOST_TAB_LINE_FILL
  if ghost_buf_is_selected then
    hl = h.const.HL_BUFPIN_GHOST_TAB_LINE_SEL
  end
  local basename = vim.fs.basename(vim.api.nvim_buf_get_name(ghost_buf))
  return "%"
    .. ghost_buf
    .. "@BufpinTlOnClickBuf@"
    .. "%#"
    .. hl
    .. "#  "
    .. h.get_icon_string_for_tabline_buf(
      basename,
      ghost_buf_is_selected,
      true,
      config_icons_style
    )
    .. basename
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
  local hl_buf_fill = h.const.HL_BUFPIN_TAB_LINE_FILL
  if is_ghost_buf then
    hl_buf_fill = h.const.HL_BUFPIN_GHOST_TAB_LINE_FILL
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
          .. hl_buf_fill
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
    return h.get_hl(h.const.HL_BUFPIN_TAB_LINE_FILL).bg
  end
  if buf_is_selected and is_ghost_buf then
    return h.get_hl(h.const.HL_BUFPIN_GHOST_TAB_LINE_SEL).bg
  end
  if not buf_is_selected and is_ghost_buf then
    return h.get_hl(h.const.HL_BUFPIN_GHOST_TAB_LINE_FILL).bg
  end
  error("Invalid state: Highlight group not found")
end

--- Get highlight group. Follows links.
--- Returns empty table for non-defined highlight groups.
---@param hl_name string
---@return vim.api.keyset.get_hl_info
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

--- Prune with `h.prune_nonexistent_bufs_from_state` before calling this function.
---@param pinned_bufs PinnedBuf[]
---@param config_icons_style string
---@return string
function h.build_tabline(
  pinned_bufs,
  config_icons_style,
  config_ghost_buf_enabled
)
  local tabline = ""
  for _, pinned_buf in ipairs(pinned_bufs) do
    tabline = tabline
      .. h.build_tabline_pinned_buf(pinned_buf, config_icons_style)
  end
  if h.should_include_ghost_buf(config_ghost_buf_enabled) then
    tabline = tabline .. h.build_tabline_ghost_buf(config_icons_style)
  end
  return tabline .. "%#" .. h.const.HL_BUFPIN_TAB_LINE_FILL .. "#"
end

---@param config_ghost_buf_enabled boolean
---@return boolean
function h.should_include_ghost_buf(config_ghost_buf_enabled)
  if
    h.state.ghost_bufnr ~= nil and vim.bo[h.state.ghost_bufnr].buftype == "help"
  then
    -- For some reason uknown to me, help files need special handling.
    h.state.ghost_bufnr = nil
    return false
  end
  if not config_ghost_buf_enabled then
    return false
  end
  local current_bufnr = vim.fn.bufnr()
  if
    vim.tbl_contains(h.state.pinned_bufnrs, current_bufnr)
    and h.state.ghost_bufnr == nil
  then
    -- Current buf is pinned and there is no ghost buf.
    return false
  end
  return true
end

--- Don't override existing hl definitions.
function h.set_hl_defaults()
  local hl_tab_line_sel = h.get_hl("TabLineSel")
  if not vim.tbl_isempty(hl_tab_line_sel) then
    vim.api.nvim_set_hl(0, h.const.HL_BUFPIN_TAB_LINE_SEL, {
      fg = hl_tab_line_sel.fg,
      bg = hl_tab_line_sel.bg,
      reverse = hl_tab_line_sel.reverse,
      default = true,
    })
    vim.api.nvim_set_hl(0, h.const.HL_BUFPIN_GHOST_TAB_LINE_SEL, {
      fg = hl_tab_line_sel.fg,
      bg = hl_tab_line_sel.bg,
      reverse = hl_tab_line_sel.reverse,
      italic = true,
      default = true,
    })
  end
  local hl_tab_line_fill = h.get_hl("TabLineFill")
  if not vim.tbl_isempty(hl_tab_line_fill) then
    vim.api.nvim_set_hl(0, h.const.HL_BUFPIN_TAB_LINE_FILL, {
      fg = hl_tab_line_fill.fg,
      bg = hl_tab_line_fill.bg,
      reverse = hl_tab_line_fill.reverse,
      default = true,
    })
    vim.api.nvim_set_hl(0, h.const.HL_BUFPIN_GHOST_TAB_LINE_FILL, {
      fg = hl_tab_line_fill.fg,
      bg = hl_tab_line_fill.bg,
      reverse = hl_tab_line_fill.reverse,
      italic = true,
      default = true,
    })
  end
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
  if #h.state.pinned_bufnrs > 0 then
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
  log_filepath = vim.fn.stdpath("log") .. "/bufpin.log",
  -- Keys starting with `config` are kept in sync with `bufpin.config`.
  config_log_enabled = nil,
}

h.const = {
  HL_BUFPIN_TAB_LINE_SEL = "BufpinTabLineSel",
  HL_BUFPIN_TAB_LINE_FILL = "BufpinTabLineFill",
  HL_BUFPIN_GHOST_TAB_LINE_SEL = "BufpinGhostTabLineSel",
  HL_BUFPIN_GHOST_TAB_LINE_FILL = "BufpinGhostTabLineFill",
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

---@param message string|fun():string Use function type for expensive operations.
---@param level integer? As per |vim.log.levels|.
function h.log(message, level)
  level = level or vim.log.levels.INFO
  if not h.state.config_log_enabled then
    return
  end
  if type(message) == "function" then
    message = message()
  end
  vim.defer_fn(function()
    vim.fn.writefile({
      string.format(
        "%s %s - %s\n",
        vim.fn.get({ "D", "I", "W", "E" }, level - 1),
        vim.fn.strftime("%H:%M:%S"),
        message
      ),
    }, h.state.log_filepath, "a")
  end, 0)
end

return h
