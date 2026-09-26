local h = dofile("tests/helpers.lua")
local mini_test = require("mini.test")

local child = mini_test.new_child_neovim()
local eq = mini_test.expect.equality
local new_set = mini_test.new_set

local T = new_set({
  hooks = {
    pre_case = function()
      h.restart(child)
      h.edit_and_pin(child, { "a.txt", "b.txt", "c.txt" })
    end,
    post_once = function()
      child.stop()
    end,
  },
})

T["move_to_left moves the current buf"] = function()
  child.lua("Bufpin.move_to_left()")
  eq(h.get_pinned_basenames(child), { "a.txt", "c.txt", "b.txt" })
end

T["move_to_left moves the given buf"] = function()
  child.lua("Bufpin.move_to_left(vim.fn.bufnr('b.txt'))")
  eq(h.get_pinned_basenames(child), { "b.txt", "a.txt", "c.txt" })
end

T["move_to_left at the left edge is a no-op"] = function()
  child.lua("Bufpin.move_to_left(vim.fn.bufnr('a.txt'))")
  eq(h.get_pinned_basenames(child), { "a.txt", "b.txt", "c.txt" })
end

T["move_to_right moves the current buf"] = function()
  h.edit(child, { "a.txt" })
  child.lua("Bufpin.move_to_right()")
  eq(h.get_pinned_basenames(child), { "b.txt", "a.txt", "c.txt" })
end

T["move_to_right at the right edge is a no-op"] = function()
  child.lua("Bufpin.move_to_right()")
  eq(h.get_pinned_basenames(child), { "a.txt", "b.txt", "c.txt" })
end

T["move of the ghost buf is a no-op"] = function()
  h.edit(child, { "same.txt" })
  child.lua("Bufpin.move_to_left()")
  eq(h.get_tabline_basenames(child), { "a.txt", "b.txt", "c.txt", "same.txt" })
end

return T
