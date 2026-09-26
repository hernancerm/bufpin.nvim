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

-- =================================================================================================
-- edit_left, edit_right

T["edit_left edits the buf to the left"] = function()
  h.edit_and_pin(child, { "a.txt", "b.txt", "c.txt" })
  child.lua("Bufpin.edit_left()")
  eq(h.get_current_basename(child), "b.txt")
end

T["edit_left wraps around to the ghost buf"] = function()
  h.edit_and_pin(child, { "a.txt", "b.txt" })
  h.edit(child, { "c.txt", "a.txt" })
  child.lua("Bufpin.edit_left()")
  eq(h.get_current_basename(child), "c.txt")
end

T["edit_right edits the buf to the right"] = function()
  h.edit_and_pin(child, { "a.txt", "b.txt", "c.txt" })
  h.edit(child, { "a.txt" })
  child.lua("Bufpin.edit_right()")
  eq(h.get_current_basename(child), "b.txt")
end

T["edit_right wraps around"] = function()
  h.edit_and_pin(child, { "a.txt", "b.txt", "c.txt" })
  child.lua("Bufpin.edit_right()")
  eq(h.get_current_basename(child), "a.txt")
end

T["edit_left from a buf not in the tabline edits the rightmost buf"] = function()
  h.edit_and_pin(child, { "a.txt", "b.txt" })
  child.cmd("help")
  child.cmd("only")
  child.lua("Bufpin.edit_left()")
  eq(h.get_current_basename(child), "b.txt")
end

T["edit_right from a buf not in the tabline edits the leftmost buf"] = function()
  h.edit_and_pin(child, { "a.txt", "b.txt" })
  child.cmd("help")
  child.cmd("only")
  child.lua("Bufpin.edit_right()")
  eq(h.get_current_basename(child), "a.txt")
end

T["edit_left with nothing pinned is a no-op"] = function()
  h.edit(child, { "a.txt", "b.txt" })
  child.lua("Bufpin.edit_left()")
  eq(h.get_current_basename(child), "b.txt")
end

T["edit_left given 'winfixbuf' is a no-op"] = function()
  h.edit_and_pin(child, { "a.txt", "b.txt" })
  child.wo.winfixbuf = true
  child.lua("Bufpin.edit_left()")
  eq(h.get_current_basename(child), "b.txt")
end

-- =================================================================================================
-- edit_by_index

T["edit_by_index edits the buf at the index"] = function()
  h.edit_and_pin(child, { "a.txt", "b.txt", "c.txt" })
  child.lua("Bufpin.edit_by_index(2)")
  eq(h.get_current_basename(child), "b.txt")
end

T["edit_by_index 0 edits the last buf, which may be the ghost buf"] = function()
  h.edit_and_pin(child, { "a.txt", "b.txt" })
  h.edit(child, { "c.txt", "a.txt" })
  child.lua("Bufpin.edit_by_index(0)")
  eq(h.get_current_basename(child), "c.txt")
end

T["edit_by_index out of range is a no-op"] = function()
  h.edit_and_pin(child, { "a.txt", "b.txt" })
  child.lua("Bufpin.edit_by_index(3)")
  eq(h.get_current_basename(child), "b.txt")
end

T["edit_by_index given 'winfixbuf' is a no-op"] = function()
  h.edit_and_pin(child, { "a.txt", "b.txt" })
  child.wo.winfixbuf = true
  child.lua("Bufpin.edit_by_index(1)")
  eq(h.get_current_basename(child), "b.txt")
end

return T
