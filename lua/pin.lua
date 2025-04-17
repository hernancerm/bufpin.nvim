--- *pin* A Harpoon-inspired buffer manager for IdeaVim users.
---
--- MIT License Copyright (c) 2025 Hernán Cervera.
---
--- Contents:
---
--- 1. Functions                                                     |pin-functions|
---
--- ==============================================================================

local pin = {}
local h = {}

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
      local bufnr_index = h.table_find_index(h.state.pinned_bufs, event.buf)
      if bufnr_index == nil and not h.is_plugin_window(event.buf) then
        h.state.last_non_pinned_buf = event.buf
      end
    end,
  })

  -- Remove wiped out bufs from state.
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = h.pin_augroup,
    callback = function(event)
      local bufnr_index = h.table_find_index(h.state.pinned_bufs, event.buf)
      if bufnr_index ~= nil then
        table.remove(h.state.pinned_bufs, bufnr_index)
      elseif event.buf == h.state.last_non_pinned_buf then
        h.state.last_non_pinned_buf = nil
      end
      pin.refresh_tabline()
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
    callback = pin.refresh_tabline,
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

  if pin.config.set_default_keymaps then
    local function opts(options)
      return vim.tbl_deep_extend(
        "force",
        vim.deepcopy({ silent = true }),
        options or {}
      )
    end
    vim.keymap.set("n", "<Leader>p", pin.toggle, opts())
    vim.keymap.set("n", "<Leader>w", pin.wipeout, opts())
    vim.keymap.set("n", "<Up>", pin.edit_left, opts())
    vim.keymap.set("n", "<Down>", pin.edit_right, opts())
    vim.keymap.set("n", "<Left>", pin.move_left, opts())
    vim.keymap.set("n", "<Right>", pin.move_right, opts())
    vim.keymap.set("n", "<F1>", function()
      pin.edit_by_index(1)
    end, opts())
    vim.keymap.set("n", "<F2>", function()
      pin.edit_by_index(2)
    end, opts())
    vim.keymap.set("n", "<F3>", function()
      pin.edit_by_index(3)
    end, opts())
    vim.keymap.set("n", "<F4>", function()
      pin.edit_by_index(4)
    end, opts())
  end
end

--- The merged config (defaults with user overrides) is in `pin.config`. The
--- default config is in `pin.default_config`. Below is the default config:
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
--minidoc_replace_start
local function assign_default_config()
  --minidoc_replace_end
  --minidoc_replace_start {
  pin.default_config = {
    --minidoc_replace_end
    pin_char = "󰐃",
    auto_hide_tabline = true,
    set_default_keymaps = true,
  }
  --minidoc_afterlines_end
end

--- #delimiter
--- #tag pin-functions
--- Functions ~

--- Get all pinned bufs.
---@return table
function pin.get()
  return h.state.pinned_bufs
end

--- Set the option 'tabline'.
---@param force boolean? Set the tabline regardless of session loading or any other skip check.
function pin.refresh_tabline(force)
  if vim.fn.exists("SessionLoad") == 1 and force ~= true then
    return
  end
  local tabline = ""
  -- Must be a left-aligned char. For other bar chars see:
  -- <https://github.com/lukas-reineke/indent-blankline.nvim/tree/master/doc>.
  local buf_separator_char = "▏"
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

--- Pin the current buf.
function pin.pin(bufnr)
  bufnr = bufnr or vim.fn.bufnr()
  if h.is_plugin_window(bufnr) or vim.api.nvim_buf_get_name(bufnr) == "" then
    return
  end
  h.pin_by_bufnr(bufnr)
  pin.refresh_tabline()
end

--- Unpin the current buf.
function pin.unpin(bufnr)
  bufnr = bufnr or vim.fn.bufnr()
  h.unpin_by_bufnr(bufnr)
  pin.refresh_tabline()
end

--- Toggle the pin state of the provided buf.
---@param bufnr integer Buf handler.
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

--- Wipeout (completely remove) the provided buf.
---@param bufnr integer Buf handler.
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

--- Moves the current buf to the left in the pinned bufs list.
function pin.move_left()
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

--- Moves the current buf to the right in the pinned bufs list.
function pin.move_right()
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

--- Edit the buf to the left in the pinned bufs list.
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

--- Edit the buf to the right in the pinned bufs list.
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

--- Edit the buf by index (order in which it appears in the tabline).
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
assign_default_config()

-- -----
--- #end

--- Merge user-supplied config with the plugin's default config. For every key
--- which is not supplied by the user, the value in the default config will be
--- used. The user's config has precedence; the default config is the fallback.
---@param config? table User supplied config.
---@param default_config table Bareline's default config.
---@return table
function h.get_config_with_fallback(config, default_config)
  vim.validate("config", config, "table", true)
  config =
    vim.tbl_deep_extend("force", vim.deepcopy(default_config), config or {})
  vim.validate("config.pin_char", config.pin_char, "string")
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
  vim.g.PinState = vim.json.encode({
    pinned_bufs = vim
      .iter(h.state.pinned_bufs)
      :map(function(bufnr)
        return vim.api.nvim_buf_get_name(bufnr)
      end)
      :totable(),
    last_non_pinned_buf = h.state.last_non_pinned_buf
      and vim.api.nvim_buf_get_name(h.state.last_non_pinned_buf),
  })
end

---@param parts table With keys `prefix`, `value` and `suffix`.
---@return string
function h.build_tabline_buf(parts)
  return parts.prefix .. parts.value .. parts.suffix
end

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
          prefix = "%#TabLineSel#  ",
          value = basename .. " " .. pin.config.pin_char,
          suffix = "  %*",
        })
    else
      local prefix = buf_separator_char .. " "
      if i == 1 or h.state.pinned_bufs[i - 1] == bufnr then
        prefix = "  "
      end
      output = output
        .. h.build_tabline_buf({
          prefix = prefix,
          value = basename .. " " .. pin.config.pin_char,
          suffix = "  ",
        })
    end
  end
  return output
end

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
      .. h.build_tabline_buf({ prefix = prefix, value = basename, suffix = "  " })
  end
  return output
end

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
function h.is_plugin_window(bufnr)
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

h.pin_augroup = vim.api.nvim_create_augroup("PinAugroup", {})

h.state = {
  pinned_bufs = {},
  last_non_pinned_buf = nil,
}

return pin
