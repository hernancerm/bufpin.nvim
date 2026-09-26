local h = dofile("tests/helpers.lua")
local mini_test = require("mini.test")

local child = mini_test.new_child_neovim()
local eq = mini_test.expect.equality
local expect_reference_screenshot = mini_test.expect.reference_screenshot
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
-- bufs

T["pinned bufs, selected pinned buf and ghost buf"] = function()
  h.edit_and_pin(child, { "a.txt", "b.txt" })
  h.edit(child, { "c.txt", "a.txt" })
  expect_reference_screenshot(child.get_screenshot())
end

T["selected ghost buf"] = function()
  h.edit_and_pin(child, { "a.txt", "b.txt" })
  h.edit(child, { "c.txt" })
  expect_reference_screenshot(child.get_screenshot())
end

T["no ghost buf given config.ghost_buf_enabled=false"] = function()
  child.lua("Bufpin.setup({ ghost_buf_enabled = false })")
  h.edit_and_pin(child, { "a.txt", "b.txt" })
  h.edit(child, { "c.txt" })
  expect_reference_screenshot(child.get_screenshot())
end

T["differentiator is the parent dir when basenames repeat"] = function()
  h.edit_and_pin(child, { "a.txt", "dir_a/same.txt" })
  h.edit(child, { "dir_b/same.txt" })
  expect_reference_screenshot(child.get_screenshot())
end

T["differentiator is a dot for the cwd"] = function()
  h.edit_and_pin(child, { "same.txt", "dir_a/same.txt" })
  expect_reference_screenshot(child.get_screenshot())
end

T["percent sign in the file name is drawn as is"] = function()
  h.edit_and_pin(child, { "100%.txt" })
  expect_reference_screenshot(child.get_screenshot())
end

-- =================================================================================================
-- overflow

T["overflow draws the hidden count to the right"] = function()
  child.o.columns = 30
  h.edit_and_pin(child, { "a.txt", "b.txt", "c.txt", "same.txt" })
  child.lua("Bufpin.edit_by_index(1)")
  expect_reference_screenshot(child.get_screenshot())
end

T["overflow draws the hidden count to the left"] = function()
  child.o.columns = 30
  h.edit_and_pin(child, { "a.txt", "b.txt", "c.txt", "same.txt" })
  expect_reference_screenshot(child.get_screenshot())
end

T["overflow keeps the scroll when the selected buf is visible"] = function()
  child.o.columns = 30
  h.edit_and_pin(child, { "a.txt", "b.txt", "c.txt", "same.txt" })
  child.lua("Bufpin.edit_left()")
  expect_reference_screenshot(child.get_screenshot())
end

-- =================================================================================================
-- vim tabpages

T["vim tabpages are drawn to the right"] = function()
  h.edit_and_pin(child, { "a.txt", "b.txt" })
  child.cmd("tabnew")
  child.cmd("tabnew")
  child.cmd("tabprevious")
  expect_reference_screenshot(child.get_screenshot())
end

T["vim tabpages are drawn with nothing pinned"] = function()
  child.cmd("tabnew")
  expect_reference_screenshot(child.get_screenshot())
end

-- =================================================================================================
-- config.auto_hide_tabline

T["tabline is hidden with nothing pinned"] = function()
  h.edit(child, { "a.txt" })
  eq(child.o.showtabline, 0)
end

T["tabline is shown with a pinned buf"] = function()
  h.edit_and_pin(child, { "a.txt" })
  eq(child.o.showtabline, 2)
end

T["tabline is hidden after unpinning the last pinned buf"] = function()
  h.edit_and_pin(child, { "a.txt" })
  child.lua("Bufpin.unpin()")
  eq(child.o.showtabline, 0)
end

T["'showtabline' is not set given config.auto_hide_tabline=false"] = function()
  child.lua("Bufpin.setup({ auto_hide_tabline = false })")
  child.o.showtabline = 1
  h.edit_and_pin(child, { "a.txt" })
  eq(child.o.showtabline, 1)
end

return T
