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
  table.insert(state.pinned_bufs, buf_handler)
end

local function unpin_buf(buf_handler)
  local buf_handler_index = table_find_index( state.pinned_bufs, buf_handler)
  if buf_handler_index ~= nil then
    table.remove(state.pinned_bufs, buf_handler_index)
  end
end

-- API

--- Get all pinned bufs.
---@return table
function pin.get()
  return state.pinned_bufs
end

-- Pin a buf. By default, pins the current buf.
---@param buf_handler integer? Current buf handler.
function pin.pin(buf_handler)
  buf_handler = buf_handler or vim.fn.bufnr()
  pin_buf(buf_handler)
end

-- Unpin a buf. By default, unpins the current buf.
---@param buf_handler integer? Current buf handler.
function pin.unpin(buf_handler)
  buf_handler = buf_handler or vim.fn.bufnr()
  unpin_buf(buf_handler)
end

-- Moves the buf to the left in the pinned bufs list.
function pin.move_left(buf_handler)
  buf_handler = buf_handler or vim.fn.bufnr()
  local buf_handler_index = table_find_index(state.pinned_bufs, buf_handler)
  if buf_handler_index ~= nil and buf_handler_index > 1 then
    local swap = state.pinned_bufs[buf_handler_index - 1]
    state.pinned_bufs[buf_handler_index - 1] = buf_handler
    state.pinned_bufs[buf_handler_index] = swap
  end
end

-- Moves the buf to the right in the pinned bufs list.
function pin.move_right(buf_handler)
  buf_handler = buf_handler or vim.fn.bufnr()
  local buf_handler_index = table_find_index(state.pinned_bufs, buf_handler)
  if buf_handler_index ~= nil and buf_handler_index < #state.pinned_bufs then
    local swap = state.pinned_bufs[buf_handler_index + 1]
    state.pinned_bufs[buf_handler_index + 1] = buf_handler
    state.pinned_bufs[buf_handler_index] = swap
  end
end

function pin.setup()
end

return pin
