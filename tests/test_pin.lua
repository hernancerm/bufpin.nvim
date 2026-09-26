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

--- Make `vim.fn.confirm()` in the child answer with `choice`, and count its calls.
---@param choice integer
local function stub_confirm(choice)
  child.lua_func(function(c)
    _G.confirm_calls = 0
    vim.fn.confirm = function()
      _G.confirm_calls = _G.confirm_calls + 1
      return c
    end
  end, choice)
end

-- =================================================================================================
-- pin

T["pin pins the current buf"] = function()
  h.edit_and_pin(child, { "a.txt", "b.txt" })
  eq(h.get_pinned_basenames(child), { "a.txt", "b.txt" })
end

T["pin pins the given buf"] = function()
  h.edit(child, { "a.txt", "b.txt" })
  child.lua("Bufpin.pin(vim.fn.bufnr('a.txt'))")
  eq(h.get_pinned_basenames(child), { "a.txt" })
end

T["pin pins the given list of bufs, dropping repeated ones"] = function()
  h.edit(child, { "a.txt", "b.txt" })
  child.lua("Bufpin.pin({ vim.fn.bufnr('b.txt'), 0, vim.fn.bufnr('b.txt') })")
  eq(h.get_pinned_basenames(child), { "b.txt" })
end

T["pin twice keeps one pin"] = function()
  h.edit_and_pin(child, { "a.txt", "a.txt" })
  eq(h.get_pinned_basenames(child), { "a.txt" })
end

T["pin lists an unlisted buf"] = function()
  h.edit(child, { "a.txt" })
  child.lua("vim.bo.buflisted = false")
  child.lua("Bufpin.pin()")
  eq(child.lua_get("vim.bo.buflisted"), true)
end

T["pin clears the ghost buf when pinning it"] = function()
  h.edit_and_pin(child, { "a.txt" })
  h.edit(child, { "b.txt" })
  eq(h.get_tabline_basenames(child), { "a.txt", "b.txt" })
  child.lua("Bufpin.pin()")
  eq(child.lua_get("Bufpin.get_ghost_buf()"), vim.NIL)
  eq(h.get_tabline_basenames(child), { "a.txt", "b.txt" })
end

T["pin ignores [No Name]"] = function()
  child.lua("Bufpin.pin()")
  eq(h.get_pinned_basenames(child), {})
end

T["pin ignores help bufs"] = function()
  child.cmd("help")
  child.lua("Bufpin.pin()")
  eq(h.get_pinned_basenames(child), {})
end

T["pin ignores bufs matched by config.exclude"] = function()
  child.lua_func(function()
    require("bufpin").setup({
      exclude = function(buf)
        return vim.fs.basename(vim.api.nvim_buf_get_name(buf)) == "b.txt"
      end,
    })
  end)
  h.edit_and_pin(child, { "a.txt", "b.txt" })
  eq(h.get_pinned_basenames(child), { "a.txt" })
end

T["pin asks above opts.ask_above bufs, and pins on yes"] = function()
  h.edit(child, { "a.txt", "b.txt", "c.txt" })
  stub_confirm(2)
  child.lua("Bufpin.pin(vim.api.nvim_list_bufs(), { ask_above = 2 })")
  eq(child.lua_get("_G.confirm_calls"), 1)
  eq(h.get_pinned_basenames(child), { "a.txt", "b.txt", "c.txt" })
end

T["pin asks above opts.ask_above bufs, and does not pin on no"] = function()
  h.edit(child, { "a.txt", "b.txt", "c.txt" })
  stub_confirm(1)
  child.lua("Bufpin.pin(vim.api.nvim_list_bufs(), { ask_above = 2 })")
  eq(h.get_pinned_basenames(child), {})
end

T["pin does not ask at opts.ask_above bufs"] = function()
  h.edit(child, { "a.txt", "b.txt" })
  stub_confirm(1)
  -- The first buf is [No Name], which is excluded, so 2 bufs are left.
  child.lua("Bufpin.pin(vim.api.nvim_list_bufs(), { ask_above = 2 })")
  eq(child.lua_get("_G.confirm_calls"), 0)
  eq(h.get_pinned_basenames(child), { "a.txt", "b.txt" })
end

-- =================================================================================================
-- unpin

T["unpin unpins the current buf, which becomes the ghost buf"] = function()
  h.edit_and_pin(child, { "a.txt", "b.txt" })
  child.lua("Bufpin.unpin()")
  eq(h.get_pinned_basenames(child), { "a.txt" })
  eq(h.get_tabline_basenames(child), { "a.txt", "b.txt" })
  eq(child.lua_get("Bufpin.get_ghost_buf()"), child.lua_get("vim.fn.bufnr('b.txt')"))
end

T["unpin unpins the given list of bufs"] = function()
  h.edit_and_pin(child, { "a.txt", "b.txt", "c.txt" })
  child.lua("Bufpin.unpin({ vim.fn.bufnr('a.txt'), vim.fn.bufnr('b.txt') })")
  eq(h.get_pinned_basenames(child), { "c.txt" })
end

T["unpin all with the output of get_pinned_bufs"] = function()
  h.edit_and_pin(child, { "a.txt", "b.txt", "c.txt" })
  child.lua("Bufpin.unpin(Bufpin.get_pinned_bufs())")
  eq(h.get_pinned_basenames(child), {})
end

T["unpin of a buf which is not pinned is a no-op"] = function()
  h.edit_and_pin(child, { "a.txt" })
  h.edit(child, { "b.txt" })
  child.lua("Bufpin.unpin()")
  eq(h.get_pinned_basenames(child), { "a.txt" })
end

-- =================================================================================================
-- toggle

T["toggle pins and unpins"] = function()
  h.edit(child, { "a.txt" })
  child.lua("Bufpin.toggle()")
  eq(h.get_pinned_basenames(child), { "a.txt" })
  child.lua("Bufpin.toggle()")
  eq(h.get_pinned_basenames(child), {})
end

T["toggle acts on the given buf"] = function()
  h.edit(child, { "a.txt", "b.txt" })
  child.lua("Bufpin.toggle(vim.fn.bufnr('a.txt'))")
  eq(h.get_pinned_basenames(child), { "a.txt" })
end

-- =================================================================================================
-- get_pinned_bufs, get_tabline_bufs, get_ghost_buf

T["get_pinned_bufs returns a copy"] = function()
  h.edit_and_pin(child, { "a.txt" })
  child.lua("table.insert(Bufpin.get_pinned_bufs(), 999)")
  eq(h.get_pinned_basenames(child), { "a.txt" })
end

T["get_tabline_bufs has the ghost buf last"] = function()
  h.edit_and_pin(child, { "a.txt" })
  h.edit(child, { "b.txt", "c.txt" })
  child.lua("Bufpin.pin(vim.fn.bufnr('b.txt'))")
  eq(h.get_tabline_basenames(child), { "a.txt", "b.txt", "c.txt" })
end

T["get_tabline_bufs has no ghost buf when nothing is pinned"] = function()
  h.edit(child, { "a.txt" })
  eq(h.get_tabline_basenames(child), {})
  eq(child.lua_get("Bufpin.get_ghost_buf()"), child.lua_get("vim.fn.bufnr('a.txt')"))
end

T["get_tabline_bufs has no ghost buf given config.ghost_buf_enabled=false"] = function()
  child.lua("Bufpin.setup({ ghost_buf_enabled = false })")
  h.edit_and_pin(child, { "a.txt" })
  h.edit(child, { "b.txt" })
  eq(h.get_tabline_basenames(child), { "a.txt" })
  -- The ghost buf is still tracked.
  eq(child.lua_get("Bufpin.get_ghost_buf()"), child.lua_get("vim.fn.bufnr('b.txt')"))
end

T["ghost buf is the last visited buf which is not pinned"] = function()
  h.edit_and_pin(child, { "a.txt" })
  h.edit(child, { "b.txt", "c.txt", "a.txt" })
  eq(h.get_tabline_basenames(child), { "a.txt", "c.txt" })
end

T["ghost buf does not change when visiting a help buf"] = function()
  h.edit_and_pin(child, { "a.txt" })
  h.edit(child, { "b.txt" })
  child.cmd("help")
  eq(h.get_tabline_basenames(child), { "a.txt", "b.txt" })
end

-- =================================================================================================
-- deletion outside of bufpin

T["bdelete of a pinned buf unpins it"] = function()
  h.edit_and_pin(child, { "a.txt", "b.txt" })
  child.cmd("bdelete a.txt")
  eq(h.get_pinned_basenames(child), { "b.txt" })
end

T["bwipeout of the ghost buf clears it"] = function()
  h.edit_and_pin(child, { "a.txt" })
  h.edit(child, { "b.txt" })
  child.cmd("bwipeout b.txt")
  eq(child.lua_get("Bufpin.get_ghost_buf()"), vim.NIL)
end

return T
