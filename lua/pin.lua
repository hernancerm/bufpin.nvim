-- Pin. Harpoon-inspired buffer manager.

local pin = {}

-- UTIL

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

---@return string The basename for a buf, or `[No Name]` when the buf has no name.
local function fs_buf_get_basename(buf_handler)
  local basename = "[No Name]"
  local buf_name = vim.api.nvim_buf_get_name(buf_handler)
  if buf_name ~= "" then
    basename = vim.fs.basename(buf_name)
  end
  return basename
end

-- STATE

local state = {
  pinned_bufs = {},
  last_non_pinned_buf = nil
}

local function pin_buf(buf_handler)
  if buf_handler == state.last_non_pinned_buf then
    state.last_non_pinned_buf = nil
  end
  local buf_handler_index = table_find_index(state.pinned_bufs, buf_handler)
  if buf_handler_index == nil then
    table.insert(state.pinned_bufs, buf_handler)
  end
end

local function unpin_buf(buf_handler)
  if state.last_non_pinned_buf == nil and buf_handler == vim.fn.bufnr() then
    state.last_non_pinned_buf = vim.fn.bufnr()
  end
  local buf_handler_index = table_find_index(state.pinned_bufs, buf_handler)
  if buf_handler_index ~= nil then
    table.remove(state.pinned_bufs, buf_handler_index)
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

pin.config = {
  pin_char = "󰐃",
  -- Must be a left-aligned char. For other bar chars see:
  -- <https://github.com/lukas-reineke/indent-blankline.nvim/tree/master/doc>.
  buf_separator_char = "▏",
  auto_hide_tabline = true,
}

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
  local buf_handler = vim.fn.bufnr()
  for i, pinned_buf in ipairs(state.pinned_bufs) do
    local basename = fs_buf_get_basename(pinned_buf)
    if pinned_buf == buf_handler then
      output = output .. build_tabline_buf({
        prefix = "%#TabLineSel#  ",
        value = basename .. " " .. pin.config.pin_char,
        suffix = "  %*"
      })
    else
      local prefix = pin.config.buf_separator_char .. " "
      if i == 1 or state.pinned_bufs[i - 1] == buf_handler then
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
  local buf_handler = vim.fn.bufnr()
  if state.last_non_pinned_buf ~= nil then
    local basename = fs_buf_get_basename(state.last_non_pinned_buf)
    if state.last_non_pinned_buf == buf_handler then
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
  end
  return output
end

--- Set the option 'tabline'.
function pin.refresh_tabline()
  local tabline = ""
  tabline = tabline .. build_tabline_pinned_bufs()
  tabline = tabline .. build_tabline_last_non_pinned_buf()
  -- Add ending separator character.
  local buf_handler = vim.fn.bufnr()
  if #tabline > 0
    and not (#state.pinned_bufs == 1 and buf_handler == state.pinned_bufs[1])
    and not (
      #state.pinned_bufs == 0
      and state.last_non_pinned_buf ~= nil
      and buf_handler == state.last_non_pinned_buf
    )
  then
    tabline = tabline .. pin.config.buf_separator_char
  end
  vim.o.tabline = tabline
end

--- Pin the current buf.
function pin.pin(buf_handler)
  buf_handler = buf_handler or vim.fn.bufnr()
  pin_buf(buf_handler)
  pin.refresh_tabline()
  if pin.config.auto_hide_tabline then
    show_tabline()
  end
end

--- Unpin the current buf.
function pin.unpin(buf_handler)
  buf_handler = buf_handler or vim.fn.bufnr()
  unpin_buf(buf_handler)
  pin.refresh_tabline()
  if pin.config.auto_hide_tabline then
    show_tabline()
  end
end

--- Toggle the pin state of the provided buf.
---@param buf_handler integer Buf handler.
function pin.toggle(buf_handler)
  local buf_handler_index = table_find_index(state.pinned_bufs, vim.fn.bufnr())
  if buf_handler_index ~= nil then
    pin.unpin(buf_handler)
  else
    pin.pin(buf_handler)
  end
  pin.refresh_tabline()
end

--- Moves the current buf to the left in the pinned bufs list.
function pin.move_left()
  if #state.pinned_bufs == 0 then
    return
  end
  local buf_handler = vim.fn.bufnr()
  local buf_handler_index = table_find_index(state.pinned_bufs, buf_handler)
  if buf_handler_index ~= nil and buf_handler_index > 1 then
    local swap = state.pinned_bufs[buf_handler_index - 1]
    state.pinned_bufs[buf_handler_index - 1] = buf_handler
    state.pinned_bufs[buf_handler_index] = swap
    pin.refresh_tabline()
  end
end

--- Moves the current buf to the right in the pinned bufs list.
function pin.move_right()
  if #state.pinned_bufs == 0 then
    return
  end
  local buf_handler = vim.fn.bufnr()
  local buf_handler_index = table_find_index(state.pinned_bufs, buf_handler)
  if buf_handler_index ~= nil and buf_handler_index < #state.pinned_bufs then
    local swap = state.pinned_bufs[buf_handler_index + 1]
    state.pinned_bufs[buf_handler_index + 1] = buf_handler
    state.pinned_bufs[buf_handler_index] = swap
    pin.refresh_tabline()
  end
end

--- Edit the buf to the left in the pinned bufs list.
function pin.edit_left()
  if #state.pinned_bufs == 0 then
    return
  end
  local buf_handler = vim.fn.bufnr()
  local buf_handler_index = table_find_index(state.pinned_bufs, buf_handler)
  if buf_handler_index == nil and state.last_non_pinned_buf == buf_handler then
    vim.cmd("buffer " .. state.pinned_bufs[#state.pinned_bufs])
    pin.refresh_tabline()
  elseif buf_handler_index ~= nil and buf_handler_index > 1 then
    vim.cmd("buffer " .. state.pinned_bufs[buf_handler_index - 1])
    pin.refresh_tabline()
  elseif buf_handler_index == 1 then
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
  local buf_handler = vim.fn.bufnr()
  local buf_handler_index = table_find_index(state.pinned_bufs, buf_handler)
  if
    buf_handler_index ~= nil
    and state.last_non_pinned_buf ~= nil
    and buf_handler_index == #state.pinned_bufs
  then
    vim.cmd("buffer " .. state.last_non_pinned_buf)
    pin.refresh_tabline()
  elseif buf_handler_index ~= nil and buf_handler_index < #state.pinned_bufs then
    vim.cmd("buffer " .. state.pinned_bufs[buf_handler_index + 1])
    pin.refresh_tabline()
  elseif
    #state.pinned_bufs > 1
    and (buf_handler_index == #state.pinned_bufs or buf_handler == state.last_non_pinned_buf)
  then
    -- Circular editing (from the last buf in the tabline go to the left-most buf).
    vim.cmd("buffer " .. state.pinned_bufs[1])
    pin.refresh_tabline()
  end
end

--- Edit the buf by index (order in which it appears in the tabline).
function pin.edit_by_index(index)
    if index <= #state.pinned_bufs then
      vim.cmd("buffer " .. state.pinned_bufs[index])
    end
    pin.refresh_tabline()
end

local pin_augroup = vim.api.nvim_create_augroup("PinAugroup", {})

function pin.setup()
  -- Here, the order of the definition of the autocmds is important.
  -- When autocmds have the same event, the autocmds defined first are executed first.

  -- Track the last non-pinned buf.
  vim.api.nvim_create_autocmd("BufEnter", {
    group = pin_augroup,
    callback = function(event)
      local buf_handler_index = table_find_index(state.pinned_bufs, event.buf)
      if buf_handler_index == nil then
        state.last_non_pinned_buf = event.buf
      end
    end
  })

  -- Remove wiped out bufs from state.
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = pin_augroup,
    callback = function(event)
      local buf_handler_index = table_find_index(state.pinned_bufs, event.buf)
      if buf_handler_index ~= nil then
        table.remove(state.pinned_bufs, buf_handler_index)
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
