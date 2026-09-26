local h = dofile("tests/helpers.lua")
local mini_test = require("mini.test")

local child = mini_test.new_child_neovim()
local eq = mini_test.expect.equality
local new_set = mini_test.new_set

-- A throwaway git repo, so the result does not depend on the git state of this repo.
local repo

local T = new_set({
  hooks = {
    pre_case = function()
      repo = vim.fn.tempname()
      vim.fn.mkdir(repo)
      vim.fn.writefile({ "committed" }, repo .. "/committed.txt")
      local git = { "git", "-C", repo, "-c", "user.name=t", "-c", "user.email=t@t" }
      vim.system(vim.list_extend(vim.deepcopy(git), { "init" })):wait()
      vim.system(vim.list_extend(vim.deepcopy(git), { "add", "." })):wait()
      vim.system(vim.list_extend(vim.deepcopy(git), { "commit", "-m", "init" })):wait()
      h.restart(child, { git_status_enabled = true })
      child.cmd("cd " .. repo)
    end,
    post_case = function()
      vim.fn.delete(repo, "rf")
    end,
    post_once = function()
      child.stop()
    end,
  },
})

--- Wait until the drawn tabline of the child matches `pattern`, then return it. The git status is
--- looked up async.
---@param pattern string Lua pattern.
---@return string
local function wait_tabline(pattern)
  return child.lua_func(function(pat)
    local tabline = ""
    vim.wait(2000, function()
      tabline = vim.api.nvim_eval_statusline(vim.o.tabline, { use_tabline = true }).str
      return tabline:find(pat) ~= nil
    end)
    return tabline
  end, pattern)
end

T["git status draws a clean file without symbol"] = function()
  h.edit_and_pin(child, { "committed.txt" })
  -- The git status of a clean file draws nothing, so wait for the lookup itself.
  child.lua_func(function()
    local key = vim.fs.normalize(vim.api.nvim_buf_get_name(0))
    vim.wait(2000, function()
      return require("bufpin.helpers").state.git_status[key] ~= nil
    end)
  end)
  eq(wait_tabline(".*"), "  committed.txt  ")
end

T["git status draws an untracked file as added"] = function()
  child.cmd("write new.txt")
  h.edit_and_pin(child, { "new.txt" })
  eq(wait_tabline("&"), "  new.txt &  ")
end

T["git status draws a modified file on write"] = function()
  h.edit_and_pin(child, { "committed.txt" })
  child.lua("vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'changed' })")
  child.cmd("write")
  eq(wait_tabline("~"), "  committed.txt ~  ")
end

T["git status uses config.git_status_symbols"] = function()
  child.lua("Bufpin.setup({ git_status_symbols = { added = '+' } })")
  child.cmd("write new.txt")
  h.edit_and_pin(child, { "new.txt" })
  eq(wait_tabline("%+"), "  new.txt +  ")
end

T["git status draws nothing given config.git_status_enabled=false"] = function()
  child.lua("Bufpin.setup({ git_status_enabled = false })")
  child.cmd("write new.txt")
  h.edit_and_pin(child, { "new.txt" })
  -- Give a lookup the time it would take, were it to run.
  vim.uv.sleep(300)
  eq(wait_tabline(".*"), "  new.txt  ")
end

return T
