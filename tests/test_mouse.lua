local h = dofile("tests/helpers.lua")
local mini_test = require("mini.test")

local child = mini_test.new_child_neovim()
local eq = mini_test.expect.equality
local new_set = mini_test.new_set

local T = new_set({
  hooks = {
    pre_case = function()
      h.restart(child)
    end,
    post_once = function()
      child.stop()
    end,
  },
})

-- Tabline columns, 0-based, as drawn with a.txt, b.txt and c.txt:
--   "  a.txt    b.txt    c.txt  "
--      ^2       ^11      ^20
local COL_A = 2
local COL_B = 11
local COL_C = 20

---@param button "left"|"middle"
---@param action "press"|"release"|"drag"
---@param col integer 0-based tabline column.
local function mouse(button, action, col)
  -- A click lands on what is on screen, so draw the tabline refresh scheduled by the autocmds.
  h.flush(child)
  child.cmd("redraw")
  child.api.nvim_input_mouse(button, action, "", 0, 0, col)
  h.flush(child)
end

---@param button "left"|"middle"
---@param col integer 0-based tabline column.
local function click(button, col)
  mouse(button, "press", col)
  mouse(button, "release", col)
end

---@param from integer 0-based tabline column.
---@param to integer 0-based tabline column.
local function drag(from, to)
  mouse("left", "press", from)
  mouse("left", "drag", to)
  mouse("left", "release", to)
end

-- =================================================================================================
-- bufs

T["left click edits the buf"] = function()
  h.edit_and_pin(child, { "a.txt", "b.txt", "c.txt" })
  click("left", COL_A)
  eq(h.get_current_basename(child), "a.txt")
end

T["middle click removes the buf"] = function()
  h.edit_and_pin(child, { "a.txt", "b.txt", "c.txt" })
  click("middle", COL_B)
  eq(h.get_pinned_basenames(child), { "a.txt", "c.txt" })
end

T["double click pins the ghost buf"] = function()
  h.edit_and_pin(child, { "a.txt", "b.txt" })
  h.edit(child, { "c.txt" })
  click("left", COL_C)
  click("left", COL_C)
  eq(h.get_pinned_basenames(child), { "a.txt", "b.txt", "c.txt" })
end

T["drag re-orders the pinned bufs"] = function()
  h.edit_and_pin(child, { "a.txt", "b.txt", "c.txt" })
  -- Past the midpoint of c.txt.
  drag(COL_A, COL_C + 4)
  eq(h.get_pinned_basenames(child), { "b.txt", "c.txt", "a.txt" })
end

T["drag does not re-order before the midpoint of the hovered buf"] = function()
  h.edit_and_pin(child, { "a.txt", "b.txt", "c.txt" })
  drag(COL_A, COL_B)
  eq(h.get_pinned_basenames(child), { "a.txt", "b.txt", "c.txt" })
end

T["drag does not re-order onto the ghost buf"] = function()
  h.edit_and_pin(child, { "a.txt", "b.txt" })
  h.edit(child, { "c.txt" })
  drag(COL_A, COL_C + 4)
  eq(h.get_tabline_basenames(child), { "a.txt", "b.txt", "c.txt" })
end

T["drag does not re-order given config.mouse_drag_reorder=false"] = function()
  child.lua("Bufpin.setup({ mouse_drag_reorder = false })")
  h.edit_and_pin(child, { "a.txt", "b.txt", "c.txt" })
  drag(COL_A, COL_C + 4)
  eq(h.get_pinned_basenames(child), { "a.txt", "b.txt", "c.txt" })
end

T["drag keymaps are deleted on release"] = function()
  h.edit_and_pin(child, { "a.txt", "b.txt", "c.txt" })
  drag(COL_A, COL_C + 4)
  eq(child.lua_get("vim.fn.maparg('<LeftDrag>', 'n')"), "")
  eq(child.lua_get("vim.fn.maparg('<LeftRelease>', 'n')"), "")
end

-- =================================================================================================
-- vim tabpages

-- Tabline columns, 0-based, of the vim tabpages drawn flush right given 3 tabpages:
--   " 1  2  3 "
--     ^72
--        ^75
--           ^78
local COL_TAB_1 = 72
local COL_TAB_3 = 78

T["left click goes to the vim tabpage"] = function()
  child.cmd("tabnew")
  child.cmd("tabnew")
  click("left", COL_TAB_1)
  eq(child.lua_get("vim.fn.tabpagenr()"), 1)
end

T["middle click closes the vim tabpage"] = function()
  child.cmd("tabnew")
  child.cmd("tabnew")
  click("middle", COL_TAB_1)
  eq(child.lua_get("vim.fn.tabpagenr('$')"), 2)
end

T["drag re-orders the vim tabpages"] = function()
  child.cmd("tabnew")
  child.cmd("tabnew")
  local tabpage_1 = child.lua_get("vim.api.nvim_list_tabpages()[1]")
  drag(COL_TAB_1, COL_TAB_3)
  eq(child.lua_get("vim.api.nvim_list_tabpages()[3]"), tabpage_1)
end

return T
