local h = dofile("tests/helpers.lua")
local mini_test = require("mini.test")

local child = mini_test.new_child_neovim()
local eq = mini_test.expect.equality
local new_set = mini_test.new_set

local T = new_set({
  hooks = {
    pre_case = function()
      h.restart(child, { tabpage_scope_enabled = true })
    end,
    post_once = function()
      child.stop()
    end,
  },
})

T["tabpage scope off shares the pinned bufs across tabpages"] = function()
  h.restart(child)
  h.edit_and_pin(child, { "a.txt" })
  child.cmd("tabnew")
  eq(h.get_pinned_basenames(child), { "a.txt" })
end

T["tabpage scope starts a new tabpage with no pinned bufs nor ghost buf"] = function()
  h.edit_and_pin(child, { "a.txt" })
  h.edit(child, { "c.txt" })
  child.cmd("tabnew")
  eq(h.get_pinned_basenames(child), {})
  eq(child.lua_get("Bufpin.get_ghost_buf()"), vim.NIL)
end

T["tabpage scope makes the ghost buf of a new tabpage its shown buf"] = function()
  h.edit_and_pin(child, { "a.txt" })
  h.edit(child, { "c.txt" })
  child.cmd("tab split")
  eq(h.get_pinned_basenames(child), {})
  eq(child.lua_get("vim.fs.basename(vim.fn.bufname(Bufpin.get_ghost_buf()))"), "c.txt")
end

T["tabpage scope keeps the pinned bufs and ghost buf of each tabpage"] = function()
  h.edit_and_pin(child, { "a.txt" })
  h.edit(child, { "c.txt" })
  child.cmd("tabnew")
  h.edit_and_pin(child, { "b.txt" })
  eq(h.get_tabline_basenames(child), { "b.txt" })
  child.cmd("tabprevious")
  eq(h.get_tabline_basenames(child), { "a.txt", "c.txt" })
  child.cmd("tabnext")
  eq(h.get_tabline_basenames(child), { "b.txt" })
end

T["tabpage scope removes a deleted buf from every tabpage"] = function()
  h.edit_and_pin(child, { "a.txt", "b.txt" })
  child.cmd("tabnew")
  h.edit_and_pin(child, { "a.txt" })
  child.cmd("bdelete " .. child.lua_get("vim.fn.bufnr('a.txt')"))
  child.cmd("tabfirst")
  eq(h.get_pinned_basenames(child), { "b.txt" })
end

T["tabpage scope drops the state of a closed tabpage"] = function()
  child.cmd("tabnew")
  h.edit_and_pin(child, { "a.txt" })
  local closed_tabpage = child.lua_get("vim.api.nvim_get_current_tabpage()")
  child.cmd("tabclose")
  h.flush(child)
  eq(child.lua_get("require('bufpin.helpers').state.scopes[...]", { closed_tabpage }), vim.NIL)
end

T["tabpage scope session restores the pinned bufs and ghost buf per tabpage"] = function()
  child.o.sessionoptions = child.o.sessionoptions .. ",globals"
  h.edit_and_pin(child, { "a.txt" })
  h.edit(child, { "c.txt" })
  child.cmd("tabnew")
  h.edit_and_pin(child, { "b.txt" })
  local session = vim.fn.tempname()
  child.cmd("mksession " .. session)
  h.restart(child, { tabpage_scope_enabled = true })
  child.cmd("source " .. session)
  vim.fn.delete(session)
  child.cmd("tabfirst")
  eq(h.get_tabline_basenames(child), { "a.txt", "c.txt" })
  child.cmd("tablast")
  eq(h.get_tabline_basenames(child), { "b.txt" })
end

return T
