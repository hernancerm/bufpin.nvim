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

T["remove deletes the current buf"] = function()
  h.edit_and_pin(child, { "a.txt", "b.txt" })
  child.lua("Bufpin.remove()")
  eq(h.get_pinned_basenames(child), { "a.txt" })
  eq(child.lua_get("vim.fn.buflisted('b.txt')"), 0)
  eq(child.lua_get("vim.fn.bufexists('b.txt')"), 1)
end

T["remove wipes out the buf given config.remove_with='wipeout'"] = function()
  child.lua("Bufpin.setup({ remove_with = 'wipeout' })")
  h.edit_and_pin(child, { "a.txt", "b.txt" })
  child.lua("Bufpin.remove()")
  eq(child.lua_get("vim.fn.bufexists('b.txt')"), 0)
end

T["remove removes the given list of bufs"] = function()
  h.edit_and_pin(child, { "a.txt", "b.txt", "c.txt" })
  child.lua("Bufpin.remove({ vim.fn.bufnr('a.txt'), vim.fn.bufnr('b.txt') })")
  eq(h.get_pinned_basenames(child), { "c.txt" })
end

T["remove edits the last visited tabline buf"] = function()
  h.edit_and_pin(child, { "a.txt", "b.txt", "c.txt" })
  h.edit(child, { "a.txt", "same.txt", "c.txt" })
  -- Visited after a.txt, but not in the tabline.
  child.cmd("help")
  child.cmd("only")
  h.edit(child, { "c.txt" })
  child.lua("Bufpin.remove()")
  eq(h.get_current_basename(child), "same.txt")
end

T["remove edits the right neighbor when no other tabline buf was visited"] = function()
  h.edit_and_pin(child, { "a.txt", "b.txt", "c.txt" })
  h.edit(child, { "b.txt" })
  -- As right after a session load.
  child.lua("require('bufpin.helpers').state.visit_order = {}")
  child.lua("Bufpin.remove()")
  eq(h.get_current_basename(child), "c.txt")
end

T["remove edits the alternate buf given config.sticky_remove_enabled=false"] = function()
  child.lua_func(function()
    require("bufpin").setup({
      sticky_remove_enabled = false,
      -- Not pinned nor ghost, so the sticky removal would never jump to it.
      exclude = function(buf)
        return vim.fs.basename(vim.api.nvim_buf_get_name(buf)) == "same.txt"
      end,
    })
  end)
  h.edit_and_pin(child, { "a.txt", "b.txt", "c.txt" })
  h.edit(child, { "same.txt", "c.txt" })
  child.lua("Bufpin.remove()")
  eq(h.get_current_basename(child), "same.txt")
end

T["remove of a modified buf asks, and keeps the buf on no"] = function()
  h.edit_and_pin(child, { "a.txt" })
  child.lua("vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'changed' })")
  child.lua("vim.fn.confirm = function() return 1 end")
  child.lua("Bufpin.remove()")
  eq(h.get_pinned_basenames(child), { "a.txt" })
end

T["remove of a modified buf asks, and removes the buf on yes"] = function()
  h.edit_and_pin(child, { "a.txt", "b.txt" })
  child.lua("vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'changed' })")
  child.lua("vim.fn.confirm = function() return 2 end")
  child.lua("Bufpin.remove()")
  eq(h.get_pinned_basenames(child), { "a.txt" })
end

return T
