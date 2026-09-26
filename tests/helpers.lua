local h = {}

h.resources_dir = vim.uv.cwd() .. "/tests/resources"

-- Git status is async, so a screenshot may be taken before or after the status is drawn. Tests
-- which are not about git status turn it off to get a stable tabline.
h.setup_config = {
  git_status_enabled = false,
}

--- Restart the child in `h.resources_dir`, so file names drawn on screen do not depend on the
--- machine running the tests.
---@param child MiniTest.child
---@param config table? Passed to `require("bufpin").setup()`, over `h.setup_config`.
function h.restart(child, config)
  child.restart({ "-u", "scripts/minimal_init.lua" })
  -- Do not show the intro screen.
  child.o.shortmess = "ltToOCFI"
  child.lua_func(function(dir, c)
    vim.cmd.cd(dir)
    require("bufpin").setup(c)
    -- The highlight groups are set on UIEnter, which fires before the test UI attaches.
    vim.cmd.colorscheme("default")
  end, h.resources_dir, vim.tbl_extend("force", h.setup_config, config or {}))
end

--- Edit each file in the child, in order.
---@param child MiniTest.child
---@param files string[] Relative to `h.resources_dir`.
function h.edit(child, files)
  child.lua_func(function(fs)
    for _, f in ipairs(fs) do
      vim.cmd.edit(vim.fn.fnameescape(f))
    end
  end, files)
end

--- Edit and pin each file in the child, in order.
---@param child MiniTest.child
---@param files string[] Relative to `h.resources_dir`.
function h.edit_and_pin(child, files)
  child.lua_func(function(fs)
    for _, f in ipairs(fs) do
      vim.cmd.edit(vim.fn.fnameescape(f))
      require("bufpin").pin()
    end
  end, files)
end

--- The basenames of the tabline bufs of the child, in the order they are drawn.
---@param child MiniTest.child
---@return string[]
function h.get_tabline_basenames(child)
  return child.lua_func(function()
    return vim
      .iter(require("bufpin").get_tabline_bufs())
      :map(function(bufnr)
        return vim.fs.basename(vim.api.nvim_buf_get_name(bufnr))
      end)
      :totable()
  end)
end

--- The basenames of the pinned bufs of the child, in order.
---@param child MiniTest.child
---@return string[]
function h.get_pinned_basenames(child)
  return child.lua_func(function()
    return vim
      .iter(require("bufpin").get_pinned_bufs())
      :map(function(bufnr)
        return vim.fs.basename(vim.api.nvim_buf_get_name(bufnr))
      end)
      :totable()
  end)
end

--- The basename of the current buf of the child.
---@param child MiniTest.child
---@return string
function h.get_current_basename(child)
  return child.lua_get("vim.fs.basename(vim.api.nvim_buf_get_name(0))")
end

--- Run the callbacks scheduled by the bufpin autocmds, e.g., the tabline refresh on BufEnter.
---@param child MiniTest.child
function h.flush(child)
  child.lua("vim.wait(0)")
end

return h
