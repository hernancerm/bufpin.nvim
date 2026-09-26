local h = dofile("tests/helpers.lua")
local mini_test = require("mini.test")

local child = mini_test.new_child_neovim()
local eq = mini_test.expect.equality
local new_set = mini_test.new_set

local T = new_set({
  hooks = {
    pre_case = function()
      h.restart(child)
      -- Needed to save `g:BufpinState`, see |'sessionoptions'|.
      child.o.sessionoptions = child.o.sessionoptions .. ",globals"
    end,
    post_once = function()
      child.stop()
    end,
  },
})

--- Save a session, restart the child and load the session.
---@param config table? Passed to `require("bufpin").setup()` of the restarted child.
local function reload_session(config)
  local session = vim.fn.tempname()
  child.cmd("mksession " .. session)
  h.restart(child, config)
  child.cmd("source " .. session)
  vim.fn.delete(session)
end

T["session restores the pinned bufs and the ghost buf"] = function()
  h.edit_and_pin(child, { "b.txt", "a.txt" })
  h.edit(child, { "c.txt" })
  reload_session()
  eq(h.get_pinned_basenames(child), { "b.txt", "a.txt" })
  eq(h.get_tabline_basenames(child), { "b.txt", "a.txt", "c.txt" })
end

T["session does not restore the ghost buf given config.ghost_buf_enabled=false"] = function()
  h.edit_and_pin(child, { "a.txt" })
  h.edit(child, { "c.txt" })
  reload_session({ ghost_buf_enabled = false })
  eq(child.lua_get("Bufpin.get_ghost_buf()"), vim.NIL)
end

T["session restores the pinned bufs of the backwards compatible state"] = function()
  h.edit_and_pin(child, { "a.txt" })
  child.lua_func(function(dir)
    vim.g.BufpinState = vim.json.encode({ pinned_bufs = { dir .. "/b.txt" } })
  end, h.resources_dir)
  reload_session()
  eq(h.get_pinned_basenames(child), { "b.txt" })
end

T["session draws the tabline"] = function()
  h.edit_and_pin(child, { "a.txt", "b.txt" })
  reload_session()
  h.flush(child)
  eq(child.o.showtabline, 2)
  eq(
    child.lua_get("vim.api.nvim_eval_statusline(vim.o.tabline, { use_tabline = true }).str"),
    "  a.txt    b.txt  "
  )
end

return T
