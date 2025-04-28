--- *pin* A Harpoon-inspired buffer manager for IdeaVim users.
---
--- MIT License Copyright (c) 2025 Hernán Cervera.
---
--- Contents:
---
--- 1. Introduction                                               |pin-introduction|
--- 2. Configuration                                             |pin-configuration|
--- 3. Highlight groups                                       |pin-highlight-groups|
--- 4. Functions                                                     |pin-functions|
---
--- ==============================================================================
--- #tag pin-introduction
--- Introduction ~
---
--- Pitch: <https://github.com/hernancerm/pin.nvim/blob/main/README.md>.
---
--- To enable the plugin you need to call the |pin.setup()| function. To use the
--- defaults, call it without arguments:
--- >lua
---   require("pin").setup()
--- <
--- All which is accessible by `require("pin")` is also by the Lua global `Pin`.
--- This is useful for setting key maps which expect an arg, e.g.:
--- >lua
---   vim.keymap.set("n", "<F1>", ":call v:lua.Pin.edit_by_index(1)<CR>")
--- <
--- For the pinned bufs to be persisted in session, add this to your `init.lua`:
--- >lua
---   vim.opt.sessionoptions:append("globals")
--- <

local pin = {}
local h = {}

--- Module setup.
---@param config table? Merged with the default config (|pin.default_config|). The
--- former takes precedence on duplicate keys.
function pin.setup(config)
  -- Here, the order of the definition of the autocmds is important. When autocmds
  -- have the same event, the autocmds defined first are executed first.

  -- Cleanup.
  if #vim.api.nvim_get_autocmds({ group = h.pin_augroup }) > 0 then
    vim.api.nvim_clear_autocmds({ group = h.pin_augroup })
  end

  -- Merge user and default configs.
  pin.config = h.get_config_with_fallback(config, pin.default_config)

  -- Track the last non-pinned buf.
  vim.api.nvim_create_autocmd("BufEnter", {
    group = h.pin_augroup,
    callback = function(event)
      if h.should_exclude_buf(event.buf) then
        return
      end
      local bufnr_index = h.table_find_index(h.state.pinned_bufs, event.buf)
      if bufnr_index == nil then
        h.state.last_non_pinned_buf = event.buf
      end
    end,
  })

  -- Remove bufs from state.
  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = h.pin_augroup,
    callback = function(event)
      local bufnr_index = h.table_find_index(h.state.pinned_bufs, event.buf)
      if bufnr_index ~= nil then
        table.remove(h.state.pinned_bufs, bufnr_index)
      elseif event.buf == h.state.last_non_pinned_buf then
        h.state.last_non_pinned_buf = nil
      end
      -- Mag buffers (from a personal plugin) are properly removed in this
      -- callback given the use of `vim.defer_fn()`, instead of just calling
      -- `pin.refresh_tabline()`. The issue is on <C-6> from Mag to non-Mag bufs.
      vim.defer_fn(pin.refresh_tabline, 50)
    end,
  })

  -- Redraw the tabline when switching bufs and wins.
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
    group = h.pin_augroup,
    callback = function()
      if h.is_floating_win(0) then
        return
      end
      pin.refresh_tabline()
    end,
  })

  -- Re-build state from session.
  vim.api.nvim_create_autocmd("SessionLoadPost", {
    group = h.pin_augroup,
    callback = function()
      if vim.g.PinState ~= nil then
        local decoded_state = vim.json.decode(vim.g.PinState)
        -- Reset `state.pinned_bufs` to its default.
        h.state.pinned_bufs = {}
        for _, pinned_buf_name in ipairs(decoded_state.pinned_bufs) do
          table.insert(h.state.pinned_bufs, vim.fn.bufadd(pinned_buf_name))
        end
        -- Reset `state.last_non_pinned_buf` to its default.
        h.state.last_non_pinned_buf = nil
        if decoded_state.last_non_pinned_buf ~= nil then
          h.state.last_non_pinned_buf =
            vim.fn.bufadd(decoded_state.last_non_pinned_buf)
        end
      end
      pin.refresh_tabline(true)
    end,
  })

  -- Set default key maps.
  if pin.config.set_default_keymaps then
    h.set_default_keymaps()
  end
end

--- #delimiter
--- #tag pin.config
--- #tag pin.default_config
--- #tag pin-configuration
--- Configuration ~

--- The merged config (defaults with user overrides) is in `pin.config`. The
--- default config is in `pin.default_config`. Below is the default config:
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
--minidoc_replace_start
function h.assign_default_config()
  --minidoc_replace_end
  --minidoc_replace_start {
  pin.default_config = {
    --minidoc_replace_end
    pin_indicator = "[P]",
    auto_hide_tabline = true,
    set_default_keymaps = true,
    exclude = function(_) end,
  }
  --minidoc_afterlines_end
end

--- #tag pin.config.pin_indicator
--- `(string)`
--- Sequence of chars used in the tabline to indicate that a buf is pinned.
--- Suggested char (requires Nerd Fonts): "nf-md-pin" (U+F0403) (󰐃).
--- Listed here: <https://www.nerdfonts.com/cheat-sheet>.
---
--- #tag pin.config.auto_hide_tabline
--- `(boolean)`
--- When true, when there are no pinned bufs, hide the tabline.
---
--- #tag pin.config.set_default_keymaps
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
  kset("n",  "<Leader>p",  ":cal v:lua.Pin.toggle()<CR>", o)
  kset("n",  "<Leader>w",  ":cal v:lua.Pin.delete()<CR>", o)
  kset("n",  "<Up>",       ":cal v:lua.Pin.edit_left()<CR>", o)
  kset("n",  "<Down>",     ":cal v:lua.Pin.edit_right()<CR>", o)
  kset("n",  "<Left>",     ":cal v:lua.Pin.move_to_left()<CR>", o)
  kset("n",  "<Right>",    ":cal v:lua.Pin.move_to_right()<CR>", o)
  kset("n",  "<F1>",       ":cal v:lua.Pin.edit_by_index(1)<CR>", o)
  kset("n",  "<F2>",       ":cal v:lua.Pin.edit_by_index(2)<CR>", o)
  kset("n",  "<F3>",       ":cal v:lua.Pin.edit_by_index(3)<CR>", o)
  kset("n",  "<F4>",       ":cal v:lua.Pin.edit_by_index(4)<CR>", o)
  --minidoc_afterlines_end
  -- stylua: ignore end
end

--- #tag pin.config.exclude
--- `(fun(bufnr:integer):boolean)`
--- When the function returns true, the buf (`bufnr`) is ignored. This means that
--- calling |pin.pin()| on it has no effect and the buf never gets tracked as the
--- last visited non-pinned buf.

--- #delimiter
--- #tag pin-highlight-groups
--- Highlight groups ~
---
--- Only built-in highlight groups are used.
---
--- * Active buffer: |hl-TabLineSel|
--- * Tabline background: |hl-TabLineFill|

--- #delimiter
--- #tag pin-functions
--- Functions ~

--- Get all the pinned bufs. This is the actual list, not a copy.
---@return table List of buf handlers.
function pin.get_pinned_bufs()
  return h.state.pinned_bufs
end

--- Get the last visited non pinned buf.
---@return integer? Buf handler.
function pin.get_last_non_pinned_buf()
  return h.state.last_non_pinned_buf
end

--- Set the option 'tabline'. The tabline is not drawn during a session
--- (|session-file|) load. To force draw send `force` as `true`.
---@param force boolean?
function pin.refresh_tabline(force)
  if vim.fn.exists("SessionLoad") == 1 and force ~= true then
    return
  end
  local tabline = ""
  -- Must be a left-aligned char. For other bar chars see:
  -- <https://github.com/lukas-reineke/indent-blankline.nvim/tree/master/doc>.
  local buf_separator_char = "▏"
  h.prune_nonexistent_bufs_from_state()
  tabline = tabline .. h.build_tabline_pinned_bufs(buf_separator_char)
  tabline = tabline .. h.build_tabline_last_non_pinned_buf(buf_separator_char)
  tabline = tabline
    .. h.build_tabline_ending_separator_char(#tabline, buf_separator_char)
  vim.o.tabline = tabline
  if pin.config.auto_hide_tabline then
    h.show_tabline()
  end
  h.serialize_state()
end

---@param bufnr integer
function pin.pin(bufnr)
  bufnr = bufnr or vim.fn.bufnr()
  if h.should_exclude_buf(bufnr) then
    return
  end
  h.pin_by_bufnr(bufnr)
  pin.refresh_tabline()
end

---@param bufnr integer
function pin.unpin(bufnr)
  bufnr = bufnr or vim.fn.bufnr()
  h.unpin_by_bufnr(bufnr)
  pin.refresh_tabline()
end

---@param bufnr integer
function pin.toggle(bufnr)
  bufnr = bufnr or vim.fn.bufnr()
  local bufnr_index = h.table_find_index(h.state.pinned_bufs, bufnr)
  if bufnr_index ~= nil then
    pin.unpin(bufnr)
  else
    pin.pin(bufnr)
  end
  pin.refresh_tabline()
end

--- Use this function to |:bdelete| the buf.
---@param bufnr integer
function pin.delete(bufnr)
  bufnr = bufnr or vim.fn.bufnr()
  if vim.bo.modified then
    vim.cmd(bufnr .. "bdelete")
  else
    pin.unpin(bufnr)
    vim.cmd(bufnr .. "bdelete")
  end
  pin.refresh_tabline()
end

--- Use this function to |:bwipeout| the buf.
---@param bufnr integer
function pin.wipeout(bufnr)
  bufnr = bufnr or vim.fn.bufnr()
  if vim.bo.modified then
    vim.cmd(bufnr .. "bwipeout")
  else
    pin.unpin(bufnr)
    vim.cmd(bufnr .. "bwipeout")
  end
  pin.refresh_tabline()
end

function pin.move_to_left()
  if #h.state.pinned_bufs == 0 then
    return
  end
  local bufnr = vim.fn.bufnr()
  local bufnr_index = h.table_find_index(h.state.pinned_bufs, bufnr)
  if bufnr_index ~= nil and bufnr_index > 1 then
    local swap = h.state.pinned_bufs[bufnr_index - 1]
    h.state.pinned_bufs[bufnr_index - 1] = bufnr
    h.state.pinned_bufs[bufnr_index] = swap
    pin.refresh_tabline()
  end
end

function pin.move_to_right()
  if #h.state.pinned_bufs == 0 then
    return
  end
  local bufnr = vim.fn.bufnr()
  local bufnr_index = h.table_find_index(h.state.pinned_bufs, bufnr)
  if bufnr_index ~= nil and bufnr_index < #h.state.pinned_bufs then
    local swap = h.state.pinned_bufs[bufnr_index + 1]
    h.state.pinned_bufs[bufnr_index + 1] = bufnr
    h.state.pinned_bufs[bufnr_index] = swap
    pin.refresh_tabline()
  end
end

function pin.edit_left()
  if #h.state.pinned_bufs == 0 then
    return
  end
  local bufnr = vim.fn.bufnr()
  local bufnr_index = h.table_find_index(h.state.pinned_bufs, bufnr)
  if bufnr_index == nil and h.state.last_non_pinned_buf == bufnr then
    vim.cmd("buffer " .. h.state.pinned_bufs[#h.state.pinned_bufs])
    pin.refresh_tabline()
  elseif bufnr_index ~= nil and bufnr_index > 1 then
    vim.cmd("buffer " .. h.state.pinned_bufs[bufnr_index - 1])
    pin.refresh_tabline()
  elseif bufnr_index == 1 then
    if h.state.last_non_pinned_buf ~= nil then
      vim.cmd("buffer " .. h.state.last_non_pinned_buf)
      pin.refresh_tabline()
    else
      -- Circular editing.
      vim.cmd("buffer " .. h.state.pinned_bufs[#h.state.pinned_bufs])
      pin.refresh_tabline()
    end
  end
end

function pin.edit_right()
  if #h.state.pinned_bufs == 0 then
    return
  end
  local bufnr = vim.fn.bufnr()
  local bufnr_index = h.table_find_index(h.state.pinned_bufs, bufnr)
  if
    bufnr_index ~= nil
    and h.state.last_non_pinned_buf ~= nil
    and bufnr_index == #h.state.pinned_bufs
  then
    vim.cmd("buffer " .. h.state.last_non_pinned_buf)
    pin.refresh_tabline()
  elseif bufnr_index ~= nil and bufnr_index < #h.state.pinned_bufs then
    vim.cmd("buffer " .. h.state.pinned_bufs[bufnr_index + 1])
    pin.refresh_tabline()
  elseif
    #h.state.pinned_bufs > 1
    and (
      bufnr_index == #h.state.pinned_bufs
      or bufnr == h.state.last_non_pinned_buf
    )
  then
    -- Circular editing.
    vim.cmd("buffer " .. h.state.pinned_bufs[1])
    pin.refresh_tabline()
  end
end

function pin.edit_by_index(index)
  if index <= #h.state.pinned_bufs then
    -- Edit a pinned buf.
    vim.cmd("buffer " .. h.state.pinned_bufs[index])
  elseif
    index == #h.state.pinned_bufs + 1 and h.state.last_non_pinned_buf ~= nil
  then
    -- Edit the last non pinned buf.
    vim.cmd("buffer " .. h.state.last_non_pinned_buf)
  end
  pin.refresh_tabline()
end

-- Set module default config.
h.assign_default_config()

-- -----
--- #end

-- Vimscript functions.
vim.cmd([[
function! PinTlOnClickEdit(minwid,clicks,button,modifiers)
  if a:clicks == 1
    if a:button == 'l'
      execute 'buffer' a:minwid
    elseif a:button == 'm'
      execute 'bdelete' a:minwid
    endif
  endif
endfunction
]])

--- Merge user-supplied config with the plugin's default config. For every key
--- which is not supplied by the user, the value in the default config will be
--- used. The user's config has precedence; the default config is the fallback.
---@param config? table User supplied config.
---@param default_config table Fallback config.
---@return table
function h.get_config_with_fallback(config, default_config)
  vim.validate("config", config, "table", true)
  config =
    vim.tbl_deep_extend("force", vim.deepcopy(default_config), config or {})
  vim.validate("config.pin_indicator", config.pin_indicator, "string")
  vim.validate("config.auto_hide_tabline", config.auto_hide_tabline, "boolean")
  vim.validate(
    "config.set_default_keymaps",
    config.set_default_keymaps,
    "boolean"
  )
  return config
end

--- For session persistence. Store state in `vim.g.PinState`. Deserialize in the
--- autocmd event `SessionLoadPost.` In `pinned_bufs` and `last_non_pinned_buf`,
--- full file names are serialized. Note: Neovim has no `SessionWritePre` event:
--- <https://github.com/neovim/neovim/issues/22814>.
function h.serialize_state()
  local last_non_pinned_buf = nil
  if
    h.state.last_non_pinned_buf ~= nil
    and vim.fn.bufexists(h.state.last_non_pinned_buf) == 1
  then
    last_non_pinned_buf = vim.api.nvim_buf_get_name(h.state.last_non_pinned_buf)
  end
  vim.g.PinState = vim.json.encode({
    pinned_bufs = vim
      .iter(h.state.pinned_bufs)
      :filter(function(bufnr)
        return vim.fn.bufexists(bufnr) == 1
      end)
      :map(function(bufnr)
        return vim.api.nvim_buf_get_name(bufnr)
      end)
      :totable(),
    last_non_pinned_buf = last_non_pinned_buf,
  })
end

--- The `bufnr` is used for mouse click support.
---@param parts table With keys `bufnr`, `prefix`, `value` and `suffix`.
---@return string
function h.build_tabline_buf(parts)
  return "%"
    .. parts.bufnr
    .. "@PinTlOnClickEdit@"
    .. parts.prefix
    .. parts.value
    .. parts.suffix
    .. "%X"
end

--- Assumption: All pinned bufs exist.
--- Prune before calling this function: `h.prune_nonexistent_bufs_from_state`.
---@param buf_separator_char string
---@return string
function h.build_tabline_pinned_bufs(buf_separator_char)
  local output = ""
  local bufnr = vim.fn.bufnr()
  for i, pinned_buf in ipairs(h.state.pinned_bufs) do
    local basename = vim.fs.basename(vim.api.nvim_buf_get_name(pinned_buf))
    if pinned_buf == bufnr then
      output = output
        .. h.build_tabline_buf({
          bufnr = pinned_buf,
          prefix = "%#TabLineSel#  ",
          value = basename .. " " .. pin.config.pin_indicator,
          suffix = "  %*",
        })
    else
      local prefix = buf_separator_char .. " "
      if i == 1 or h.state.pinned_bufs[i - 1] == bufnr then
        prefix = "  "
      end
      output = output
        .. h.build_tabline_buf({
          bufnr = pinned_buf,
          prefix = prefix,
          value = basename .. " " .. pin.config.pin_indicator,
          suffix = "  ",
        })
    end
  end
  return output
end

--- Assumption: If the last non-pinned buf is non-nil, it exists.
--- Prune before calling this function: `h.prune_nonexistent_bufs_from_state`.
---@param buf_separator_char string
---@return string
function h.build_tabline_last_non_pinned_buf(buf_separator_char)
  local output = ""
  if h.state.last_non_pinned_buf == nil then
    return output
  end
  local bufnr = vim.fn.bufnr()
  local basename =
    vim.fs.basename(vim.api.nvim_buf_get_name(h.state.last_non_pinned_buf))
  if h.state.last_non_pinned_buf == bufnr then
    local prefix = "%#TabLineSel#  "
    local suffix = "  %*"
    output = output .. prefix .. basename .. suffix
  else
    local prefix = buf_separator_char .. " "
    if #h.state.pinned_bufs == 0 then
      prefix = "  "
    end
    output = output
      .. h.build_tabline_buf({
        bufnr = h.state.last_non_pinned_buf,
        prefix = prefix,
        value = basename,
        suffix = "  ",
      })
  end
  return output
end

--- Assumption: If the last non-pinned buf is non-nil, it exists.
--- Prune before calling this function: `h.prune_nonexistent_bufs_from_state`.
---@param tabline_length integer
---@param buf_separator_char string
---@return string
function h.build_tabline_ending_separator_char(tabline_length, buf_separator_char)
  local output = ""
  local bufnr = vim.fn.bufnr()
  if
    tabline_length > 0
    and not (#h.state.pinned_bufs == 1 and bufnr == h.state.pinned_bufs[1])
    and not (
      #h.state.pinned_bufs == 0
      and h.state.last_non_pinned_buf ~= nil
      and bufnr == h.state.last_non_pinned_buf
    )
  then
    output = buf_separator_char
  end
  return output
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
  local filetype = vim.bo[bufnr].filetype
  local special_non_plugin_filetypes = { nil, "", "help", "man" }
  local matched_filetype, _ = vim.filetype.match({ buf = bufnr })
  -- Although the quickfix and location lists are not plugin windows, using the
  -- plugin window format in these windows looks more sensible.
  if vim.bo.buftype == "quickfix" then
    return true
  end
  return matched_filetype == nil
    and not vim.bo.buflisted
    and not vim.tbl_contains(special_non_plugin_filetypes, filetype)
end

---@param win_id integer
---@return boolean
function h.is_floating_win(win_id)
  -- See |api-floatwin| to learn how to check whether a win is floating.
  return vim.api.nvim_win_get_config(win_id).relative ~= ""
end

function h.prune_nonexistent_bufs_from_state()
  h.state.pinned_bufs = vim
    .iter(h.state.pinned_bufs)
    :filter(function(bufnr)
      return vim.fn.bufexists(bufnr) == 1
    end)
    :totable()
  if
    h.state.last_non_pinned_buf ~= nil
    and vim.fn.bufexists(h.state.last_non_pinned_buf) == 0
  then
    h.state.last_non_pinned_buf = nil
  end
end

---@param bufnr integer
function h.pin_by_bufnr(bufnr)
  if bufnr == h.state.last_non_pinned_buf then
    h.state.last_non_pinned_buf = nil
  end
  local bufnr_index = h.table_find_index(h.state.pinned_bufs, bufnr)
  if bufnr_index == nil then
    table.insert(h.state.pinned_bufs, bufnr)
  end
end

---@param bufnr integer
function h.unpin_by_bufnr(bufnr)
  if bufnr == vim.fn.bufnr() then
    h.state.last_non_pinned_buf = vim.fn.bufnr()
  end
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

--- Whether the buf should be excluded from pins and the last non-pinned buf
--- according to the exclusion check from `pin.config.exclude` plus other checks.
---@param bufnr integer
---@return boolean
function h.should_exclude_buf(bufnr)
  return pin.config.exclude(bufnr)
    or vim.api.nvim_buf_get_name(bufnr) == ""
    or vim.bo[bufnr].buftype == "help"
    or h.is_plugin_buf(bufnr)
    or h.is_floating_win(0)
end

h.pin_augroup = vim.api.nvim_create_augroup("PinAugroup", {})

h.state = {
  pinned_bufs = {},
  last_non_pinned_buf = nil,
}

_G.Pin = pin
return pin
