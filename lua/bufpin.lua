--- *bufpin* Manually track a list of bufs and visualize the list in the tabline.
---
--- MIT License Copyright (c) 2025 Hernán Cervera.
---
--- Contents:
---
--- 1. Introduction                                            |bufpin-introduction|
--- 2. Configuration                                          |bufpin-configuration|
--- 3. Highlight groups                                    |bufpin-highlight-groups|
--- 4. Functions                                                  |bufpin-functions|
---
--- ==============================================================================
--- #tag bufpin-introduction
--- Introduction ~
---
--- Context: <https://github.com/hernancerm/bufpin.nvim/blob/main/README.md>.
---
--- To enable the plugin you need to call the |bufpin.setup()| function. To use
--- the defaults, call it without arguments:
--- >lua
---   require("bufpin").setup()
--- <
--- After calling |bufpin.setup()| the Lua global `Bufpin` gets defined. This
--- global variable provides acces to everything that `require("bufpin")` does.
--- This is useful for setting key maps on functions which expect an arg, e.g.:
--- >lua
---   vim.keymap.set("n", "<F1>", ":call v:lua.Bufpin.edit_by_index(1)<CR>")
--- <

local bufpin = {}
local h = {}

--- Module setup.
---@param config table? Merged with the default config (|bufpin.default_config|).
--- The former takes priority on duplicate keys.
function bufpin.setup(config)
  -- Here, the order of the definition of the autocmds is important. When autocmds
  -- have the same event, the autocmds defined first are executed first.

  -- Cleanup.
  if #vim.api.nvim_get_autocmds({ group = h.bufpin_augroup }) > 0 then
    vim.api.nvim_clear_autocmds({ group = h.bufpin_augroup })
  end

  -- Merge user and default configs.
  bufpin.config = h.get_config_with_fallback(config, bufpin.default_config)

  -- Remove bufs from state.
  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = h.bufpin_augroup,
    callback = function(event)
      local bufnr_index = h.table_find_index(h.state.pinned_bufs, event.buf)
      if bufnr_index ~= nil then
        table.remove(h.state.pinned_bufs, bufnr_index)
      end
    end,
  })

  -- Do 2 things:
  -- 1. Keep value of `h.state.last_visited_non_pinned_buf` updated.
  -- 2. Redraw the tabline when switching bufs and wins.
  vim.api.nvim_create_autocmd({
    "BufNew",
    "BufEnter",
    "BufWinEnter",
    "CmdlineLeave",
    "FocusGained",
    "VimResume",
    "TermLeave",
    "WinEnter",
  }, {
    group = h.bufpin_augroup,
    callback = function()
      local current_buf = vim.fn.bufnr()
      if not vim.tbl_contains(h.state.pinned_bufs, current_buf)
          and not h.should_exclude_buf(current_buf) then
        h.state.ghost_buf = current_buf
      end
      bufpin.refresh_tabline()
    end,
  })
  if h.const.HAS_BLINKCMP then
    vim.api.nvim_create_autocmd("User", {
      group = h.bufpin_augroup,
      pattern = "BlinkCmpMenuOpen",
      callback = bufpin.refresh_tabline,
    })
  end

  -- Set highlight groups.
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = h.bufpin_augroup,
    callback = h.set_hl_with_defaults
  })
  h.set_hl_with_defaults()

  -- Re-build state from session.
  vim.api.nvim_create_autocmd("SessionLoadPost", {
    group = h.bufpin_augroup,
    callback = function()
      if vim.g.BufpinState ~= nil then
        local decoded_state = vim.json.decode(vim.g.BufpinState)
        -- Restore `state.pinned_bufs`.
        h.state.pinned_bufs = {}
        for _, pinned_buf_name in ipairs(decoded_state.pinned_bufs) do
          table.insert(h.state.pinned_bufs, vim.fn.bufadd(pinned_buf_name))
        end
        -- Restore `state.ghost_buf`.
        if bufpin.config.ghost_buf_enabled and decoded_state.ghost_buf ~= nil then
          h.state.ghost_buf = vim.fn.bufadd(decoded_state.ghost_buf)
        end
      end
      bufpin.refresh_tabline(true)
    end,
  })

  -- Set default key maps.
  if bufpin.config.set_default_keymaps then
    h.set_default_keymaps()
  end

  _G.Bufpin = bufpin
end

--- #delimiter
--- #tag bufpin.config
--- #tag bufpin.default_config
--- #tag bufpin-configuration
--- Configuration ~

-- TODO: The "color" value for `icons_style` shows bad bg color.

--- The merged config (defaults with user overrides) is in `bufpin.config`. The
--- default config is in `bufpin.default_config`. Below is the default config:
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
--minidoc_replace_start
---@return BufpinConfig
function h.assign_default_config()
  --minidoc_replace_end
  --minidoc_replace_start {
  bufpin.default_config = {
    --minidoc_replace_end
    auto_hide_tabline = true,
    set_default_keymaps = true,
    exclude = function(_) end,
    use_mini_bufremove = false,
    icons_style = "monochrome",
    ghost_buf_enabled = true,
    remove_with = "delete"
  }
  --minidoc_afterlines_end
end

--- #tag bufpin.config.auto_hide_tabline
--- `(boolean)`
--- When true, when there are no pinned bufs, hide the tabline.

--- #tag bufpin.config.set_default_keymaps
--- `(boolean)`
--- When true, the default key maps, listed below, are set.

--- Default key maps:
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
--minidoc_replace_start
function h.set_default_keymaps()
  -- stylua: ignore start
  --minidoc_replace_end
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
  --minidoc_afterlines_end
  -- stylua: ignore end
end

--- #tag bufpin.config.exclude
--- `(fun(bufnr:integer):boolean)`
--- When the function returns true, the buf (`bufnr`) is ignored. This means that
--- calling |bufpin.pin()| on it has no effect. Some bufs are excluded regardless
--- of this option: bufs without a name ([No Name]), Vim help files, man pages,
--- detected plugin bufs (e.g., nvimtree) and floating wins.

--- #tag bufpin.config.use_mini_bufremove
--- `(boolean)`
--- You need to have installed <https://github.com/echasnovski/mini.bufremove> for
--- this option to work as `true`. When `true`, all buf deletions and wipeouts are
--- done using the `mini.bufremove` plugin, thus preserving window layouts.

--- #tag bufpin.config.icons_style
--- `"color"|"monochrome"|"monochrome_selected"`
--- How the file type icons look. Currently there is a bug with "color".

--- #tag bufpin.config.ghost_buf_enabled
--- `(boolean)`
--- Whether to display the ghost buffer, i.e., the last visited non-pinned buf. If
--- any, it's displayed always as the last item in the tabline.

--- #tag bufpin.config.remove_with
--- `"delete"|"wipeout"`
--- Set how buf removal is done for both the function |bufpin.remove()| and the
--- mouse middle click input on a buf in the tabline.

--- #delimiter
--- #tag bufpin-highlight-groups
--- Highlight groups ~
---
--- * Active buffer: |hl-TabLineSel|
--- * Tabline background: |hl-TabLineFill|
--- * Active ghost buffer: `BufpinGhostTabLineSel`
--- * Inactive ghost buffer: `BufpinGhostTabLineFill`

--- #delimiter
--- #tag bufpin-functions
--- Functions ~

--- Pin the current buf or the provided buf.
---@param bufnr integer?
function bufpin.pin(bufnr)
  local current_buf = vim.fn.bufnr()
  bufnr = bufnr or current_buf
  if h.should_exclude_buf(bufnr) then
    return
  end
  if current_buf == bufnr and h.state.ghost_buf == bufnr then
    h.state.ghost_buf = nil
  end
  h.pin_by_bufnr(bufnr)
  bufpin.refresh_tabline()
end

--- Unpin the current buf or the provided buf.
---@param bufnr integer?
function bufpin.unpin(bufnr)
  local current_buf = vim.fn.bufnr()
  bufnr = bufnr or current_buf
  h.unpin_by_bufnr(bufnr)
  if current_buf == bufnr then
    h.state.ghost_buf = bufnr
  end
  bufpin.refresh_tabline()
end

--- Toggle the pin state of the current buf or the provided buf.
---@param bufnr integer?
function bufpin.toggle(bufnr)
  bufnr = bufnr or vim.fn.bufnr()
  local bufnr_index = h.table_find_index(h.state.pinned_bufs, bufnr)
  if bufnr_index ~= nil then
    bufpin.unpin(bufnr)
  else
    bufpin.pin(bufnr)
  end
  bufpin.refresh_tabline()
end

--- Remove a buf either by deleting it or wiping it out. This function obeys the
--- config |bufpin.config.remove_with|. Use this function to remove pinned bufs.
--- When no bufnr is provided, the current buf is attempted to be removed.
---@param bufnr integer?
function bufpin.remove(bufnr)
  bufnr = bufnr or vim.fn.bufnr()
  h.eliminate_buf(bufpin.config.remove_with, bufnr)
end

function bufpin.move_to_left()
  if #h.state.pinned_bufs == 0 then
    return
  end
  local bufnr = vim.fn.bufnr()
  local bufnr_index = h.table_find_index(h.state.pinned_bufs, bufnr)
  if bufnr_index ~= nil and bufnr_index > 1 then
    local swap = h.state.pinned_bufs[bufnr_index - 1]
    h.state.pinned_bufs[bufnr_index - 1] = bufnr
    h.state.pinned_bufs[bufnr_index] = swap
    bufpin.refresh_tabline()
  end
end

function bufpin.move_to_right()
  if #h.state.pinned_bufs == 0 then
    return
  end
  local bufnr = vim.fn.bufnr()
  local bufnr_index = h.table_find_index(h.state.pinned_bufs, bufnr)
  if bufnr_index ~= nil and bufnr_index < #h.state.pinned_bufs then
    local swap = h.state.pinned_bufs[bufnr_index + 1]
    h.state.pinned_bufs[bufnr_index + 1] = bufnr
    h.state.pinned_bufs[bufnr_index] = swap
    bufpin.refresh_tabline()
  end
end

function bufpin.edit_left()
  if #h.state.pinned_bufs == 0 then
    return
  end
  local current_buf = vim.fn.bufnr()
  local bufnr_index = h.table_find_index(h.state.pinned_bufs, current_buf)
  if bufnr_index == nil then
    -- Ghost buf is active.
    vim.cmd("buffer " .. h.state.pinned_bufs[#h.state.pinned_bufs])
  elseif bufnr_index > 1 then
    vim.cmd("buffer " .. h.state.pinned_bufs[bufnr_index - 1])
    bufpin.refresh_tabline()
  elseif bufnr_index == 1 then
    -- Circular editing.
    if h.state.ghost_buf ~= nil then
      vim.cmd("buffer " .. h.state.ghost_buf)
    else
      vim.cmd("buffer " .. h.state.pinned_bufs[#h.state.pinned_bufs])
    end
    bufpin.refresh_tabline()
  end
end

function bufpin.edit_right()
  if #h.state.pinned_bufs == 0 then
    return
  end
  local bufnr_index = h.table_find_index(h.state.pinned_bufs, vim.fn.bufnr())
  if bufnr_index == nil then
    -- Ghost buf is active.
    vim.cmd("buffer " .. h.state.pinned_bufs[1])
  elseif bufnr_index < #h.state.pinned_bufs then
    vim.cmd("buffer " .. h.state.pinned_bufs[bufnr_index + 1])
    bufpin.refresh_tabline()
  elseif bufnr_index == #h.state.pinned_bufs then
    if h.state.ghost_buf ~= nil then
      vim.cmd("buffer " .. h.state.ghost_buf)
    else
      -- Circular editing.
      vim.cmd("buffer " .. h.state.pinned_bufs[1])
    end
    bufpin.refresh_tabline()
  end
end

---@param index integer Index of a pinned buf in |bufpin.get_pinned_bufs()|.
function bufpin.edit_by_index(index)
  if index <= #h.state.pinned_bufs then
    vim.cmd("buffer " .. h.state.pinned_bufs[index])
  elseif index == #h.state.pinned_bufs + 1 and h.state.ghost_buf ~= nil then
    vim.cmd("buffer " .. h.state.ghost_buf)
  end
  bufpin.refresh_tabline()
end

--- Get all the pinned bufs. This is the actual list, not a copy.
---@return integer[] Buf handlers.
function bufpin.get_pinned_bufs()
  return h.state.pinned_bufs
end

--- Set the option 'tabline'. The tabline is not drawn during a session
--- (|session-file|) load. To force draw send `force` as `true`.
---@param force boolean?
function bufpin.refresh_tabline(force)
  if vim.fn.exists("SessionLoad") == 1 and force ~= true then
    return
  end
  local tabline = ""
  h.prune_invalid_ghost_buf_from_state()
  h.prune_invalid_pinned_bufs_from_state()
  local pinned_bufs = h.normalize_pinned_bufs()
  tabline = tabline .. h.build_tabline(pinned_bufs)
  vim.o.tabline = tabline
  if bufpin.config.auto_hide_tabline then
    h.show_tabline()
  end
  h.serialize_state()
end

-- Set module default config.
h.assign_default_config()

-- -----
--- #end

-- Vimscript functions.
vim.cmd([[
function! BufpinTlOnClickBuf(minwid,clicks,button,modifiers)
  if a:clicks == 1
    if a:button == 'l'
      execute 'buffer' a:minwid
    elseif a:button == 'm'
      call v:lua.Bufpin.remove(a:minwid)
    endif
  endif
endfunction
]])

---@class PinnedBuf
---@field bufnr integer
---@field basename string
---@field differentiator string?
---@field selected boolean

---@class BufpinConfig
---@field auto_hide_tabline boolean
---@field set_default_keymaps boolean
---@field exclude fun(bufnr:integer): boolean
---@field use_mini_bufremove boolean
---@field icons_style "color"|"monochrome"|"monochrome_selected"
---@field ghost_buf_enabled boolean
---@field remove_with "delete"|"wipeout"

--- Merge user-supplied config with the plugin's default config. For every key
--- which is not supplied by the user, the value in the default config will be
--- used. The user's config has precedence; the default config is the fallback.
---@param config? table User supplied config.
---@param default_config table Fallback config.
---@return BufpinConfig
function h.get_config_with_fallback(config, default_config)
  vim.validate("config", config, "table", true)
  config =
    vim.tbl_deep_extend("force", vim.deepcopy(default_config), config or {})
  vim.validate("config.auto_hide_tabline", config.auto_hide_tabline, "boolean")
  vim.validate(
    "config.set_default_keymaps",
    config.set_default_keymaps,
    "boolean"
  )
  return config
end

--- For session persistence. Store state in `vim.g.BufpinState`. Deserialize in
--- the autocmd event `SessionLoadPost.` In `pinned_bufs`, full file names are
--- serialized. Note: Neovim has no `SessionWritePre` event:
--- <https://github.com/neovim/neovim/issues/22814>.
function h.serialize_state()
  local state = {
    pinned_bufs = vim
      .iter(h.state.pinned_bufs)
      :filter(function(bufnr)
        return vim.fn.bufexists(bufnr) == 1
      end)
      :map(function(bufnr)
        return vim.api.nvim_buf_get_name(bufnr)
      end)
      :totable()
  }
  if bufpin.config.ghost_buf_enabled
      and h.state.ghost_buf ~= nil
      and vim.fn.bufexists(h.state.ghost_buf) == 1 then
    state.ghost_buf = vim.api.nvim_buf_get_name(h.state.ghost_buf)
  end
  vim.g.BufpinState = vim.json.encode(state)
end

--- Delete or wipeout a buf. Conditionally use mini.bufremove.
---@param operation "delete"|"wipeout"
---@param bufnr integer
function h.eliminate_buf(operation, bufnr)
  if vim.bo[bufnr].modified then
    if bufpin.config.use_mini_bufremove then
      require("mini.bufremove")[operation](bufnr)
    else
      vim.cmd(bufnr .. "b" .. operation)
    end
  else
    if bufpin.config.use_mini_bufremove then
      bufpin.unpin(bufnr)
      if h.state.ghost_buf == bufnr then
        h.state.ghost_buf = nil
      end
      require("mini.bufremove")[operation](bufnr)
    else
      bufpin.unpin(bufnr)
      if h.state.ghost_buf == bufnr then
        h.state.ghost_buf = nil
      end
      vim.cmd(bufnr .. "b" .. operation)
    end
  end
  bufpin.refresh_tabline()
end

---@param pinned_buf PinnedBuf
---@return string
function h.build_tabline_pinned_buf(pinned_buf)
  local basename = pinned_buf.basename
  if pinned_buf.differentiator ~= nil then
    basename = pinned_buf.differentiator .. "/" .. basename
  end
  if pinned_buf.selected then
    return "%"
      .. pinned_buf.bufnr
      .. "@BufpinTlOnClickBuf@"
      .. "%#TabLineSel#  "
      .. h.get_icon_string_for_build_tabline_buf(true, basename)
      .. basename
      .. "  %*"
      .. "%X"
  else
    return "%"
      .. pinned_buf.bufnr
      .. "@BufpinTlOnClickBuf@  "
      .. h.get_icon_string_for_build_tabline_buf(false, basename)
      .. basename
      .. "  %*"
      .. "%X"
  end
end

---@param buf_is_selected boolean
---@param buf_name string
function h.get_icon_string_for_build_tabline_buf(buf_is_selected, buf_name)
  if not h.const.HAS_MINI_ICONS then
    return ""
  end
  local icon, icon_hi = nil, nil
  if h.const.HAS_MINI_ICONS then
    icon, icon_hi = MiniIcons.get("file", buf_name)
  end
  local icon_string = ""
  if buf_is_selected then
    if h.const.HAS_MINI_ICONS then
      if bufpin.config.icons_style == "color" then
        icon_string = "%#" .. icon_hi .. "#" .. icon .. "%#TabLineSel# "
      elseif bufpin.config.icons_style == "monochrome"
          or bufpin.config.icons_style == "monochrome_selected" then
        icon_string = icon .. " "
      end
    end
  else
    if h.const.HAS_MINI_ICONS then
      if bufpin.config.icons_style == "color"
          or bufpin.config.icons_style == "monochrome_selected" then
        icon_string = "%#" .. icon_hi .. "#" .. icon .. "%#TabLineFill# "
      elseif bufpin.config.icons_style == "monochrome" then
        icon_string = icon .. " "
      end
    end
  end
  return icon_string
end

--- Prune with `h.prune_nonexistent_bufs_from_state` before calling this function.
---@param pinned_bufs PinnedBuf[]
---@return string
function h.build_tabline(pinned_bufs)
  local tabline = ""
  for _, pinned_buf in ipairs(pinned_bufs) do
    tabline = tabline .. h.build_tabline_pinned_buf(pinned_buf)
  end
  if h.should_include_ghost_buf() then
    tabline = tabline .. h.build_tabline_ghost_buf()
  end
  return tabline
end

---@return boolean
function h.should_include_ghost_buf()
  if not bufpin.config.ghost_buf_enabled then
    return false
  end
  local current_buf = vim.fn.bufnr()
  if vim.tbl_contains(h.state.pinned_bufs, current_buf)
      and h.state.ghost_buf == nil then
    -- Current buf is pinned and there is no ghost buf.
    return false
  end
  return true
end

---@return string
function h.build_tabline_ghost_buf()
  local ghost_buf = h.state.ghost_buf
  if ghost_buf == nil then
    return ""
  end
  local hl_group = "BufpinGhostTabLineFill"
  if ghost_buf == vim.fn.bufnr() then
    hl_group = "BufpinGhostTabLineSel"
  end
  local basename = vim.fs.basename(vim.api.nvim_buf_get_name(ghost_buf))
  return "%"
    .. ghost_buf
    .. "@BufpinTlOnClickBuf@"
    .. "%#" .. hl_group .. "#  "
    .. h.get_icon_string_for_build_tabline_buf(true, basename)
    .. basename
    .. "  %*"
    .. "%X"
end

--- Set highlight groups to defaults only if not already set.
function h.set_hl_with_defaults()
  local tab_line_fill_hl = vim.api.nvim_get_hl(0, { name = "TabLineFill" })
  vim.api.nvim_set_hl(0, "BufpinGhostTabLineFill", {
    fg = tab_line_fill_hl.fg,
    bg = tab_line_fill_hl.bg,
    italic = true
  })
  local tab_line_sel_hl = vim.api.nvim_get_hl(0, { name = "TabLineSel" })
  vim.api.nvim_set_hl(0, "BufpinGhostTabLineSel", {
    fg = tab_line_sel_hl.fg,
    bg = tab_line_sel_hl.bg,
    italic = true
  })
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
  h.state.pinned_bufs = vim
    .iter(h.state.pinned_bufs)
    :filter(function(bufnr)
      return vim.fn.bufexists(bufnr) == 1
    end)
    :totable()
end

function h.prune_invalid_ghost_buf_from_state()
  if vim.tbl_contains(h.state.pinned_bufs, h.state.ghost_buf)
      or vim.fn.bufexists(h.state.ghost_buf) == 0 then
    h.state.ghost_buf = nil
  end
end

---@param bufnr integer
function h.pin_by_bufnr(bufnr)
  local bufnr_index = h.table_find_index(h.state.pinned_bufs, bufnr)
  if bufnr_index == nil then
    table.insert(h.state.pinned_bufs, bufnr)
  end
end

---@param bufnr integer
function h.unpin_by_bufnr(bufnr)
  local bufnr_index = h.table_find_index(h.state.pinned_bufs, bufnr)
  if bufnr_index ~= nil then
    table.remove(h.state.pinned_bufs, bufnr_index)
  end
end

--- Show the tabline only when there is a pinned buf to show.
function h.show_tabline()
  if #h.state.pinned_bufs > 0 then
    vim.o.showtabline = 2
  else
    vim.o.showtabline = 0
  end
end

function h.print_user_error(message)
  vim.api.nvim_echo({ { message, "Error" } }, true, {})
end

---@return integer[] Buf handlers.
function h.get_bufs_with_repeating_basename()
  local basenames_count = {}
  local bufs_with_repeating_basename = {}
  for _, pinned_buf in ipairs(h.state.pinned_bufs) do
    local basename = vim.fs.basename(vim.api.nvim_buf_get_name(pinned_buf))
    if basenames_count[basename] == nil then
      basenames_count[basename] = 1
    else
      basenames_count[basename] = basenames_count[basename] + 1
    end
  end
  for _, pinned_buf in ipairs(h.state.pinned_bufs) do
    local basename = vim.fs.basename(vim.api.nvim_buf_get_name(pinned_buf))
    if basenames_count[basename] > 1 then
      table.insert(bufs_with_repeating_basename, pinned_buf)
    end
  end
  return bufs_with_repeating_basename
end

---@return PinnedBuf[]
function h.normalize_pinned_bufs()
  local pinned_bufs = {}
  local current_buf = vim.fn.bufnr()
  local bufs_with_repeating_basename = h.get_bufs_with_repeating_basename()
  for _, bufnr in ipairs(h.state.pinned_bufs) do
    local full_filename = vim.api.nvim_buf_get_name(bufnr)
    if vim.tbl_contains(bufs_with_repeating_basename, bufnr) then
      -- Set differentiator when >1 pinned bufs have the same basename. Use always
      -- the parent directory to attempt to differentiate. This strategy ignores
      -- the rare case of different parent dirs having the same name.
      local parent_dir = vim.fn.fnamemodify(full_filename, ":h:t")
      if vim.fn.fnamemodify(full_filename, ":h") == vim.uv.cwd() then
        parent_dir = "."
      end
      table.insert(pinned_bufs, {
        bufnr = bufnr,
        basename = vim.fs.basename(full_filename),
        selected = current_buf == bufnr,
        differentiator = parent_dir,
      })
    else
      table.insert(pinned_bufs, {
        bufnr = bufnr,
        basename = vim.fs.basename(full_filename),
        selected = current_buf == bufnr,
      })
    end
  end
  return pinned_bufs
end

--- Whether the buf should be excluded from the pinned bufs according to the
--- exclusion check from `bufpin.config.exclude` and other checks.
---@param bufnr integer
---@return boolean
function h.should_exclude_buf(bufnr)
  return bufpin.config.exclude(bufnr)
    or vim.api.nvim_buf_get_name(bufnr) == ""
    or vim.bo[bufnr].buftype == "quickfix"
    or vim.bo[bufnr].buftype == "nofile"
    or vim.bo[bufnr].buftype == "help"
    or h.is_plugin_buf(bufnr)
    or h.is_floating_win(0)
end

h.bufpin_augroup = vim.api.nvim_create_augroup("PinAugroup", {})

h.state = {
  pinned_bufs = {},
  -- Approach for managing the state of ghost_buf: Set in an autocmd, then set to
  -- nil (or rearely to another buf) on a case-by-case basis per API function.
  ghost_buf = nil
}

h.const = {
  HAS_BLINKCMP = pcall(require, "blink.cmp"),
  HAS_MINI_ICONS = pcall(require, "mini.icons")
}

-- Useful to debug.

function bufpin._get_state()
  return h.state
end

return bufpin
