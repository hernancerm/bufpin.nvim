-- When possible, plugin options are tested along the behavior they affect.
-- This test file is to test 2 things about setup(): validations and merge.

local mini_test = require("mini.test")

local child = mini_test.new_child_neovim()
local eq = mini_test.expect.equality
local expect_error = mini_test.expect.error
local new_set = mini_test.new_set

local T = new_set({
  hooks = {
    pre_case = function()
      child.restart({ "-u", "scripts/minimal_init.lua" })
    end,
    post_once = function()
      child.stop()
    end,
  },
})

-- =================================================================================================
-- validations

-- stylua: ignore start
T["setup validates type"] = new_set({
  parametrize = {
    { { auto_hide_tabline = 1 },     "bufpin.config.auto_hide_tabline: expected boolean," },
    { { exclude = 1 },               "bufpin.config.exclude: expected function," },
    { { use_mini_bufremove = 1 },    "bufpin.config.use_mini_bufremove: expected boolean," },
    { { icons_style = 1 },           "bufpin.config.icons_style: expected string," },
    { { sticky_remove_enabled = 1 }, "bufpin.config.sticky_remove_enabled: expected boolean," },
    { { mouse_drag_reorder = 1 },    "bufpin.config.mouse_drag_reorder: expected boolean," },
    { { ghost_buf_enabled = 1 },     "bufpin.config.ghost_buf_enabled: expected boolean," },
    { { remove_with = 1 },           "bufpin.config.remove_with: expected string," },
    { { git_status_enabled = 1 },    "bufpin.config.git_status_enabled: expected boolean," },
    { { git_status_symbols = 1 },    "bufpin.config.git_status_symbols: expected table," },
    {
      { git_status_symbols = { added = 1 } },
      "bufpin.config.git_status_symbols.added: expected string,",
    },
  },
})
-- stylua: ignore end

T["setup validates type"]["parametrized"] = function(config, message)
  expect_error(function()
    child.lua_func(function(c)
      require("bufpin").setup(c)
    end, config)
  end, message)
end

-- =================================================================================================
-- merge

T["setup merges config.git_status_symbols"] = function()
  child.lua_func(function()
    require("bufpin").setup({
      git_status_symbols = {
        added = "+",
      },
    })
  end)
  eq(child.lua_get("require('bufpin').config.git_status_symbols"), {
    added = "+",
    modified = "~",
    conflict = "!",
  })
end

T["setup merges over the config of a previous call"] = function()
  child.lua_func(function()
    require("bufpin").setup({ remove_with = "wipeout" })
    require("bufpin").setup({ ghost_buf_enabled = false })
  end)
  eq(child.lua_get("require('bufpin').config.remove_with"), "wipeout")
  eq(child.lua_get("require('bufpin').config.ghost_buf_enabled"), false)
end

T["setup keeps default_config unchanged"] = function()
  child.lua_func(function()
    require("bufpin").setup({ remove_with = "wipeout" })
  end)
  eq(child.lua_get("require('bufpin').default_config.remove_with"), "delete")
end

return T
