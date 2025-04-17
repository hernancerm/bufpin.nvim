-- Pin. Harpoon-inspired buffer manager.

local pin = {}

-- TODO: Differentiate files named the same but in different dirs.

-- GLOBALS

-- Internals.
local constants = {
  LOG_FILEPATH = vim.fn.stdpath("data") .. "/pin.lua/pin.log"
}

-- Internals.
local state = {
  pinned_bufs = {},
  last_non_pinned_buf = nil
}

-- This is part of the API.
pin.config = {
  pin_char = "󰐃",
  -- Must be a left-aligned char. For other bar chars see:
  -- <https://github.com/lukas-reineke/indent-blankline.nvim/tree/master/doc>.
  buf_separator_char = "▏",
  auto_hide_tabline = true,
}

-- HELPERS

---@param message string
---@param level integer? As per |vim.log.levels|.
local function log(message, level)
  level = level or vim.log.levels.INFO
  vim.fn.writefile(
    { string.format("%s - %s\n", vim.fn.get({ "D", "I", "W", "E" }, level - 1), message) },
    constants.LOG_FILEPATH,
    "a"
  )
end

--- For session persistence. Store state in `vim.g.PinState`.
--- For `pinned_bufs` and `last_non_pinned_buf`, the full file names are serialized.
--- Note: Neovim has no `SessionWritePre` event: <https://github.com/neovim/neovim/issues/22814>.
local function serialize_state()
  vim.g.PinState = vim.json.encode({
    pinned_bufs = vim.iter(state.pinned_bufs):map(function(bufnr)
      return vim.api.nvim_buf_get_name(bufnr)
    end):totable(),
    last_non_pinned_buf = state.last_non_pinned_buf
      and vim.api.nvim_buf_get_name(state.last_non_pinned_buf)
  })
end

--- Find the index of a value in a list-like table.
---@param tbl table Numerically indexed table (list).
---@param target_value any The value being searched in `tbl`.
---@return integer? Index or nil if the item was not found.
local function table_find_index(tbl, target_value)
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
local function is_plugin_window(bufnr)
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

local function pin_by_bufnr(bufnr)
  if bufnr == state.last_non_pinned_buf then
    state.last_non_pinned_buf = nil
  end
  local bufnr_index = table_find_index(state.pinned_bufs, bufnr)
  if bufnr_index == nil then
    table.insert(state.pinned_bufs, bufnr)
  end
end

local function unpin_by_bufnr(bufnr)
  if bufnr == vim.fn.bufnr() then
    state.last_non_pinned_buf = vim.fn.bufnr()
  end
  local bufnr_index = table_find_index(state.pinned_bufs, bufnr)
  if bufnr_index ~= nil then
    table.remove(state.pinned_bufs, bufnr_index)
  end
end

--- Show the tabline only when there is a pinned buf to show.
local function show_tabline()
  if #state.pinned_bufs > 0 then
    vim.o.showtabline = 2
  else
    vim.o.showtabline = 0
  end
end

-- API

--- Get all pinned bufs.
---@return table
function pin.get()
  return state.pinned_bufs
end

local function build_tabline_buf(parts)
  return parts.prefix .. parts.value .. parts.suffix
end

local function build_tabline_pinned_bufs()
  local output = ""
  local bufnr = vim.fn.bufnr()
  for i, pinned_buf in ipairs(state.pinned_bufs) do
    local basename = vim.fs.basename(vim.api.nvim_buf_get_name(pinned_buf))
    if pinned_buf == bufnr then
      output = output .. build_tabline_buf({
        prefix = "%#TabLineSel#  ",
        value = basename .. " " .. pin.config.pin_char,
        suffix = "  %*"
      })
    else
      local prefix = pin.config.buf_separator_char .. " "
      if i == 1 or state.pinned_bufs[i - 1] == bufnr then
        prefix = "  "
      end
      output = output .. build_tabline_buf({
        prefix = prefix,
        value = basename .. " " .. pin.config.pin_char,
        suffix = "  "
      })
    end
  end
  return output
end

local function build_tabline_last_non_pinned_buf()
  local output = ""
  if state.last_non_pinned_buf == nil then
    return output
  end
  local bufnr = vim.fn.bufnr()
  local basename = vim.fs.basename(vim.api.nvim_buf_get_name(state.last_non_pinned_buf))
  if state.last_non_pinned_buf == bufnr then
    local prefix = "%#TabLineSel#  "
    local suffix = "  %*"
    output = output .. prefix .. basename .. suffix
  else
    local prefix = pin.config.buf_separator_char .. " "
    if #state.pinned_bufs == 0 then
      prefix = "  "
    end
    output = output .. build_tabline_buf({ prefix = prefix, value = basename, suffix = "  " })
  end
  return output
end

local function build_tabline_ending_separator_char(tabline_length)
  local output = ""
  local bufnr = vim.fn.bufnr()
  if tabline_length > 0
    and not (#state.pinned_bufs == 1 and bufnr == state.pinned_bufs[1])
    and not (
      #state.pinned_bufs == 0
      and state.last_non_pinned_buf ~= nil
      and bufnr == state.last_non_pinned_buf
    )
  then
    output = pin.config.buf_separator_char
  end
  return output
end

--- Set the option 'tabline'.
---@param force boolean? Set the tabline regardless of session loading or any other skip check.
function pin.refresh_tabline(force)
  if vim.fn.exists("SessionLoad") == 1 and force ~= true then
    return
  end
  local tabline = ""
  tabline = tabline .. build_tabline_pinned_bufs()
  tabline = tabline .. build_tabline_last_non_pinned_buf()
  tabline = tabline .. build_tabline_ending_separator_char(#tabline)
  vim.o.tabline = tabline
  if pin.config.auto_hide_tabline then
    show_tabline()
  end
  serialize_state()
end

--- Pin the current buf.
function pin.pin(bufnr)
  bufnr = bufnr or vim.fn.bufnr()
  if is_plugin_window(bufnr) or vim.api.nvim_buf_get_name(bufnr) == "" then
    return
  end
  pin_by_bufnr(bufnr)
  pin.refresh_tabline()
end

--- Unpin the current buf.
function pin.unpin(bufnr)
  bufnr = bufnr or vim.fn.bufnr()
  unpin_by_bufnr(bufnr)
  pin.refresh_tabline()
end

--- Toggle the pin state of the provided buf.
---@param bufnr integer Buf handler.
function pin.toggle(bufnr)
  local bufnr_index = table_find_index(state.pinned_bufs, vim.fn.bufnr())
  if bufnr_index ~= nil then
    pin.unpin(bufnr)
  else
    pin.pin(bufnr)
  end
  pin.refresh_tabline()
end

--- Moves the current buf to the left in the pinned bufs list.
function pin.move_left()
  if #state.pinned_bufs == 0 then
    return
  end
  local bufnr = vim.fn.bufnr()
  local bufnr_index = table_find_index(state.pinned_bufs, bufnr)
  if bufnr_index ~= nil and bufnr_index > 1 then
    local swap = state.pinned_bufs[bufnr_index - 1]
    state.pinned_bufs[bufnr_index - 1] = bufnr
    state.pinned_bufs[bufnr_index] = swap
    pin.refresh_tabline()
  end
end

--- Moves the current buf to the right in the pinned bufs list.
function pin.move_right()
  if #state.pinned_bufs == 0 then
    return
  end
  local bufnr = vim.fn.bufnr()
  local bufnr_index = table_find_index(state.pinned_bufs, bufnr)
  if bufnr_index ~= nil and bufnr_index < #state.pinned_bufs then
    local swap = state.pinned_bufs[bufnr_index + 1]
    state.pinned_bufs[bufnr_index + 1] = bufnr
    state.pinned_bufs[bufnr_index] = swap
    pin.refresh_tabline()
  end
end

--- Edit the buf to the left in the pinned bufs list.
function pin.edit_left()
  if #state.pinned_bufs == 0 then
    return
  end
  local bufnr = vim.fn.bufnr()
  local bufnr_index = table_find_index(state.pinned_bufs, bufnr)
  if bufnr_index == nil and state.last_non_pinned_buf == bufnr then
    vim.cmd("buffer " .. state.pinned_bufs[#state.pinned_bufs])
    pin.refresh_tabline()
  elseif bufnr_index ~= nil and bufnr_index > 1 then
    vim.cmd("buffer " .. state.pinned_bufs[bufnr_index - 1])
    pin.refresh_tabline()
  elseif bufnr_index == 1 then
    if state.last_non_pinned_buf ~= nil then
      vim.cmd("buffer " .. state.last_non_pinned_buf)
      pin.refresh_tabline()
    else
    -- Circular editing (from the first buf in the tabline go to the right-most buf).
      vim.cmd("buffer " .. state.pinned_bufs[#state.pinned_bufs])
      pin.refresh_tabline()
    end
  end
end

--- Edit the buf to the right in the pinned bufs list.
function pin.edit_right()
  if #state.pinned_bufs == 0 then
    return
  end
  local bufnr = vim.fn.bufnr()
  local bufnr_index = table_find_index(state.pinned_bufs, bufnr)
  if
    bufnr_index ~= nil
    and state.last_non_pinned_buf ~= nil
    and bufnr_index == #state.pinned_bufs
  then
    vim.cmd("buffer " .. state.last_non_pinned_buf)
    pin.refresh_tabline()
  elseif bufnr_index ~= nil and bufnr_index < #state.pinned_bufs then
    vim.cmd("buffer " .. state.pinned_bufs[bufnr_index + 1])
    pin.refresh_tabline()
  elseif
    #state.pinned_bufs > 1
    and (bufnr_index == #state.pinned_bufs or bufnr == state.last_non_pinned_buf)
  then
    -- Circular editing (from the last buf in the tabline go to the left-most buf).
    vim.cmd("buffer " .. state.pinned_bufs[1])
    pin.refresh_tabline()
  end
end

--- Edit the buf by index (order in which it appears in the tabline).
function pin.edit_by_index(index)
    if index <= #state.pinned_bufs then
      -- Edit a pinned buf.
      vim.cmd("buffer " .. state.pinned_bufs[index])
    elseif index == #state.pinned_bufs + 1 and state.last_non_pinned_buf ~= nil then
      -- Edit the last non pinned buf.
      vim.cmd("buffer " .. state.last_non_pinned_buf)
    end
    pin.refresh_tabline()
end

local pin_augroup = vim.api.nvim_create_augroup("PinAugroup", {})

function pin.setup()
  -- Here, the order of the definition of the autocmds is important.
  -- When autocmds have the same event, the autocmds defined first are executed first.

  -- Create log filepath dir.
  vim.fn.mkdir(vim.fn.fnamemodify(constants.LOG_FILEPATH, ":h"), "p")

  -- Track the last non-pinned buf.
  vim.api.nvim_create_autocmd("BufEnter", {
    group = pin_augroup,
    callback = function(event)
      local bufnr_index = table_find_index(state.pinned_bufs, event.buf)
      if bufnr_index == nil and not is_plugin_window(event.buf) then
        state.last_non_pinned_buf = event.buf
      end
    end
  })

  -- Remove wiped out bufs from state.
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = pin_augroup,
    callback = function(event)
      local bufnr_index = table_find_index(state.pinned_bufs, event.buf)
      if bufnr_index ~= nil then
        table.remove(state.pinned_bufs, bufnr_index)
      elseif event.buf == state.last_non_pinned_buf then
        state.last_non_pinned_buf = nil
      end
      pin.refresh_tabline()
    end
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
    group = pin_augroup,
    callback = pin.refresh_tabline
  })

  -- Re-build state from session.
  vim.api.nvim_create_autocmd("SessionLoadPost", {
    group = pin_augroup,
    callback = function()
      if vim.g.PinState ~= nil then
        local decoded_state = vim.json.decode(vim.g.PinState)
        for _, pinned_buf_name in ipairs(decoded_state.pinned_bufs) do
          table.insert(state.pinned_bufs, vim.fn.bufadd(pinned_buf_name))
        end
        if decoded_state.last_non_pinned_buf ~= nil then
          state.last_non_pinned_buf = vim.fn.bufadd(decoded_state.last_non_pinned_buf)
        end
      end
      pin.refresh_tabline(true)
    end
  })
end

-- KEY MAPS

local function opts(options)
  return vim.tbl_deep_extend("force", vim.deepcopy({ silent = true }), options or {})
end

vim.keymap.set("n", "<Leader>p", pin.toggle, opts())
vim.keymap.set("n", "<Leader>w", function()
  if vim.bo.modified then
    vim.cmd("bwipeout")
  else
    pin.unpin()
    vim.cmd("bwipeout")
  end
end, opts())

vim.keymap.set("n", "<Up>", pin.edit_left, opts())
vim.keymap.set("n", "<Down>", pin.edit_right, opts())
vim.keymap.set("n", "<Left>", pin.move_left, opts())
vim.keymap.set("n", "<Right>", pin.move_right, opts())

vim.keymap.set("n", "<F1>", function() pin.edit_by_index(1) end, opts())
vim.keymap.set("n", "<F2>", function() pin.edit_by_index(2) end, opts())
vim.keymap.set("n", "<F3>", function() pin.edit_by_index(3) end, opts())
vim.keymap.set("n", "<F4>", function() pin.edit_by_index(4) end, opts())

return pin
