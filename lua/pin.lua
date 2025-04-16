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

-- STATE

local state = {
  pinned_bufs = {}
}

local function pin_buf(buf_handler)
  local buf_handler_index = table_find_index(state.pinned_bufs, buf_handler)
  if buf_handler_index == nil then
    table.insert(state.pinned_bufs, buf_handler)
  end
end

local function unpin_buf(buf_handler)
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
  auto_hide_tabline = true
}

--- Get all pinned bufs.
---@return table
function pin.get()
  return state.pinned_bufs
end

--- Sets the value for 'tabline'.
function pin.refresh_tabline()
  local tabline = ""
  local buf_handler = vim.fn.bufnr()
  for i, pinned_buf in ipairs(state.pinned_bufs) do
    local basename = ""
    local buf_name = vim.api.nvim_buf_get_name(pinned_buf)
    if buf_name ~= "" then
      basename = vim.fs.basename(buf_name)
    else
      basename = vim.api.nvim_eval_statusline("%f", {}).str
    end
    if pinned_buf == buf_handler then
      local prefix = "%#TabLineSel#  "
      local suffix = "  %*"
      tabline = tabline .. prefix .. basename .. " " .. pin.config.pin_char .. suffix
    else
      -- For other bar chars, see:
      -- <https://github.com/lukas-reineke/indent-blankline.nvim/tree/master/doc>.
      local prefix = "▏ "
      local suffix = "  "
      if i == 1 or state.pinned_bufs[i - 1] == buf_handler then
        prefix = "  "
      end
      tabline = tabline .. prefix .. basename .. " " .. pin.config.pin_char .. suffix
    end
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
--- Assumption: The current buf is a pinned buf. If this is not true, nothing is done.
function pin.move_left()
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
--- Assumption: The current buf is a pinned buf. If this is not true, nothing is done.
function pin.move_right()
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
--- Assumption: The current buf is a pinned buf. If this is not true, nothing is done.
function pin.edit_left()
  local buf_handler_index = table_find_index(state.pinned_bufs, vim.fn.bufnr())
  if buf_handler_index ~= nil and buf_handler_index > 1 then
    vim.cmd("buffer " .. state.pinned_bufs[buf_handler_index - 1])
    pin.refresh_tabline()
  end
end

--- Edit the buf to the right in the pinned bufs list.
--- Assumption: The current buf is a pinned buf. If this is not true, nothing is done.
function pin.edit_right()
  local buf_handler_index = table_find_index(state.pinned_bufs, vim.fn.bufnr())
  if buf_handler_index ~= nil and buf_handler_index < #state.pinned_bufs then
    vim.cmd("buffer " .. state.pinned_bufs[buf_handler_index + 1])
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

  -- Remove wiped out bufs from the pinned bufs list.
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = pin_augroup,
    callback = function(event)
      local buf_handler_index = table_find_index(state.pinned_bufs, event.buf)
      if buf_handler_index ~= nil then
        table.remove(state.pinned_bufs, buf_handler_index)
      end
      pin.refresh_tabline()
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
