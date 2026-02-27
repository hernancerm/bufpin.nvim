--- *bufpin* Manually track a list of bufs and visualize it in the tabline.
---
--- MIT License Copyright (c) 2025 Hernán Cervera.
---
--- Contents:
---
--- 1. Introduction                                            |bufpin-introduction|
--- 2. Configuration                                          |bufpin-configuration|
--- 3. Highlight groups                                    |bufpin-highlight-groups|
--- 4. Functions                                                  |bufpin-functions|
---
--- ==============================================================================
--- #tag bufpin-introduction
--- Introduction ~
---
--- To enable the plugin you need to call the |bufpin.setup()| function. To use
--- the defaults, call it without arguments:
--- >lua
---   require("bufpin").setup()
--- <
--- After calling |bufpin.setup()| the Lua global `Bufpin` gets defined. This
--- global variable provides acces to everything that `require("bufpin")` does.
--- This is useful for setting key maps on functions which expect an arg, e.g.:
--- >lua
---   vim.keymap.set("n", "<F1>", ":call v:lua.Bufpin.edit_by_index(1)<CR>")
--- <

local bufpin = {}
local h = {}

-- Changes to the config table spec requires changes here:
-- 1. `BufpinConfig` class
-- 2. `bufpin.default_config`
-- 3. Validations in `h.get_config_with_fallback`
-- 4. Documentation for Vim help file
-- 5. README.md

--- Module setup.
---@param config table? Merged with the default config (|bufpin.default_config|).
--- The former takes priority on duplicate keys.
function bufpin.setup(config)
  -- Here, the order of the definition of the autocmds is important. When autocmds
  -- have the same event, the autocmds defined first are executed first.

  -- Cleanup.
  if #vim.api.nvim_get_autocmds({ group = h.bufpin_augroup }) > 0 then
    vim.api.nvim_clear_autocmds({ group = h.bufpin_augroup })
  end

  -- Merge user and default configs.
  bufpin.config = h.get_config_with_fallback(config, bufpin.default_config)

  -- Remove bufs from state.
  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = h.bufpin_augroup,
    callback = function(event)
      local bufnr_index = h.table_find_index(h.state.pinned_bufnrs, event.buf)
      if bufnr_index ~= nil then
        table.remove(h.state.pinned_bufnrs, bufnr_index)
      end
    end,
  })

  -- No need to refresh the tabline until after creating all windows and loading
  -- the buffers in them. The event VimEnter indicates this startup stuff is done.
  vim.api.nvim_create_autocmd("VimEnter", {
    group = h.bufpin_augroup,
    callback = function()
      -- Do 2 things:
      -- 1. Redraw the tabline when switching bufs and wins.
      -- 2. Keep accurate the value of `h.state.ghost_bufnr`.
      vim.api.nvim_create_autocmd({
        "BufEnter",
        "BufWinEnter",
        "CmdlineLeave",
        "FocusGained",
        "VimResume",
        "TermLeave",
        -- TODO: Finish the fix. Here, "WinClosed" fixes pinned buf has lost
        -- highlight after closing LSP popup help on cursor move (key map K). To
        -- do: The highlight is initially lost when the popup window is opened.
        "WinClosed",
        "WinEnter",
      }, {
        group = h.bufpin_augroup,
        callback = function(e)
          local current_bufnr = vim.fn.bufnr()
          if
            not vim.tbl_contains(h.state.pinned_bufnrs, current_bufnr)
            and not h.should_exclude_from_pin(current_bufnr)
          then
            h.state.ghost_bufnr = current_bufnr
          end
          h.log("Refreshing tabline on event: " .. e.event)
          bufpin.refresh_tabline()
        end,
      })
    end,
  })

  -- Set highlight groups.
  -- From my testing ColorScheme is also executed when setting 'bg'.
  vim.api.nvim_create_autocmd({ "UIEnter", "ColorScheme" }, {
    group = h.bufpin_augroup,
    callback = function(e)
      h.log(
        "Setting hl defaults on event: "
          .. e.event
          .. " for 'background': "
          .. vim.o.background
      )
      h.state.hl_cache = {}
      h.set_hl_defaults()
      bufpin.refresh_tabline()
    end,
  })

  -- Fix no selected buf in tabline when using blink.cmp's completion menu.
  vim.api.nvim_create_autocmd("User", {
    group = h.bufpin_augroup,
    pattern = "BlinkCmpMenuOpen",
    callback = bufpin.refresh_tabline,
  })

  -- Re-build state from session.
  vim.api.nvim_create_autocmd("SessionLoadPost", {
    group = h.bufpin_augroup,
    callback = function()
      if vim.g.BufpinState ~= nil then
        local decoded_state = vim.json.decode(vim.g.BufpinState)
        -- Restore `state.pinned_bufnrs`.
        h.state.pinned_bufnrs = {}
        local pinned_buf_names = decoded_state.pinned_buf_names
          -- Alternative for backwards compatibility.
          or decoded_state.pinned_bufs
        for _, pinned_buf_name in ipairs(pinned_buf_names) do
          table.insert(h.state.pinned_bufnrs, vim.fn.bufadd(pinned_buf_name))
        end
        -- Restore `state.ghost_bufnr`.
        h.state.ghost_bufnr = nil
        local ghost_buf_name = decoded_state.ghost_buf_name
          -- Alternative for backwards compatibility.
          or decoded_state.ghost_buf
        if bufpin.config.ghost_buf_enabled and ghost_buf_name ~= nil then
          h.state.ghost_bufnr = vim.fn.bufadd(ghost_buf_name)
        end
      end
      bufpin.refresh_tabline(true)
    end,
  })

  -- Set default key maps.
  if bufpin.config.set_default_keymaps then
    h.set_default_keymaps()
  end

  -- Logger setup.
  if bufpin.config.logging.enabled then
    vim.fn.mkdir(vim.fn.fnamemodify(h.state.log_filepath, ":h"), "p")
  end

  _G.Bufpin = bufpin
end

--- #delimiter
--- #tag bufpin.config
--- #tag bufpin.default_config
--- #tag bufpin-configuration
--- Configuration ~

--- The merged config (defaults with user overrides) is in `bufpin.config`. The
--- default config is in `bufpin.default_config`. Below is the default config:
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
--minidoc_replace_start
function h.assign_default_config()
  --minidoc_replace_end
  --minidoc_replace_start {
  bufpin.default_config = {
    --minidoc_replace_end
    auto_hide_tabline = true,
    set_default_keymaps = true,
    exclude = function(_) end,
    exclude_runr_bufs = true,
    use_mini_bufremove = true,
    icons_style = "monochrome_selected",
    ghost_buf_enabled = true,
    remove_with = "delete",
    logging = {
      enabled = false,
      level = vim.log.levels.INFO,
    },
  }
  --minidoc_afterlines_end
end

--- #tag bufpin.config.auto_hide_tabline
--- `(boolean)`
--- When true and there are no pinned bufs, hide the tabline.

--- #tag bufpin.config.set_default_keymaps
--- `(boolean)`
--- When true, the default key maps listed below are set.

--- Default key maps:
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
--minidoc_replace_start
function h.set_default_keymaps()
  -- stylua: ignore start
  --minidoc_replace_end
  local kset = vim.keymap.set
  local opts = { silent = true }
  kset("n",  "<Leader>p",  ":cal v:lua.Bufpin.toggle()<CR>",          opts)
  kset("n",  "<Leader>w",  ":cal v:lua.Bufpin.remove()<CR>",          opts)
  kset("n",  "<Up>",       ":cal v:lua.Bufpin.edit_left()<CR>",       opts)
  kset("n",  "<Down>",     ":cal v:lua.Bufpin.edit_right()<CR>",      opts)
  kset("n",  "<Left>",     ":cal v:lua.Bufpin.move_to_left()<CR>",    opts)
  kset("n",  "<Right>",    ":cal v:lua.Bufpin.move_to_right()<CR>",   opts)
  kset("n",  "<F1>",       ":cal v:lua.Bufpin.edit_by_index(1)<CR>",  opts)
  kset("n",  "<F2>",       ":cal v:lua.Bufpin.edit_by_index(2)<CR>",  opts)
  kset("n",  "<F3>",       ":cal v:lua.Bufpin.edit_by_index(3)<CR>",  opts)
  kset("n",  "<F4>",       ":cal v:lua.Bufpin.edit_by_index(4)<CR>",  opts)
  --minidoc_afterlines_end
  -- stylua: ignore end
end

--- #tag bufpin.config.exclude
--- `(fun(bufnr:integer):boolean)`
--- When the function returns true, the buf (`bufnr`) is ignored. This means that
--- the buf is not displayed in the tabline and calling |bufpin.pin()| on it has
--- no effect. Some bufs are excluded regardless of this opt: bufs without a
--- name ([No Name]), Vim help files, man pages, detected plugin bufs (e.g.,
--- nvimtree) and floating wins.

--- #tag bufpin.config.exclude_runr_bufs
--- `(boolean)`
--- When true the bufs managed by <https://github.com/hernancerm/runr.nvim> are
--- excluded, as if set to be excluded by the opt |bufpin.config.exclude|.

--- #tag bufpin.config.use_mini_bufremove
--- `(boolean)`
--- You need to have installed <https://github.com/echasnovski/mini.bufremove>.
--- When true, all buf deletions and wipeouts are done via the `mini.bufremove`
--- plugin, thus preserving window layouts.

--- #tag bufpin.config.icons_style
--- `("color"|"monochrome"|"monochrome_selected"|"hidden")`
--- You need to have installed <https://github.com/nvim-mini/mini.icons>. Use
--- `monochrome_selected` to display only the selected buf's file type icon as
--- monochrome, the other icons are colored. Use `hidden` to not display icons
--- altogether.

--- #tag bufpin.config.ghost_buf_enabled
--- `(boolean)`
--- Whether to display the ghost buf, i.e., the last visited non-pinned pin-able
--- buf. If any, it's displayed always as the last item in the tabline.

--- #tag bufpin.config.remove_with
--- `("delete"|"wipeout")`
--- Set how buf removal is done for both the function |bufpin.remove()| and the
--- mouse middle click input on a buf in the tabline.

--- #tag bufpin.config.logging
--- Log file location: `stdpath("log")` .. `/bufpin.log`.
---
--- #tag bufpin.config.logging.enabled
---     {enabled} `(boolean)`
---       Whether to write to the log file.
---
--- #tag bufpin.config.logging.level
---     {level} `(integer)`
---       Log statements on this level and up are written to the log file.

--- #delimiter
--- #tag bufpin-highlight-groups
--- Highlight groups ~
---
--- * Active buffer: `BufpinTabLineSel`
--- * Tabline background: `BufpinTabLineFill`
--- * Active ghost buffer: `BufpinGhostTabLineSel`
--- * Inactive ghost buffer: `BufpinGhostTabLineFill`

--- #delimiter
--- #tag bufpin-functions
--- Functions ~

--- Pin the current buf or the provided buf.
---@param bufnr integer?
function bufpin.pin(bufnr)
  local current_bufnr = vim.fn.bufnr()
  bufnr = bufnr or current_bufnr
  if h.should_exclude_from_pin(bufnr) then
    return
  end
  if current_bufnr == bufnr and h.state.ghost_bufnr == bufnr then
    h.state.ghost_bufnr = nil
  end
  h.pin_by_bufnr(bufnr)
  bufpin.refresh_tabline()
end

--- Unpin the current buf or the provided buf.
---@param bufnr integer?
function bufpin.unpin(bufnr)
  local current_bufnr = vim.fn.bufnr()
  bufnr = bufnr or current_bufnr
  h.unpin_by_bufnr(bufnr)
  if current_bufnr == bufnr then
    h.state.ghost_bufnr = bufnr
  end
  bufpin.refresh_tabline()
end

--- Toggle the pin state of the current buf or the provided buf.
---@param bufnr integer?
function bufpin.toggle(bufnr)
  bufnr = bufnr or vim.fn.bufnr()
  local bufnr_index = h.table_find_index(h.state.pinned_bufnrs, bufnr)
  if bufnr_index ~= nil then
    bufpin.unpin(bufnr)
  else
    bufpin.pin(bufnr)
  end
  bufpin.refresh_tabline()
end

--- Remove a buf either by deleting it or wiping it out. This function obeys the
--- config |bufpin.config.remove_with|. Use this function to remove pinned bufs.
--- When no bufnr is provided, the current buf is attempted to be removed.
---@param bufnr integer?
function bufpin.remove(bufnr)
  bufnr = bufnr or vim.fn.bufnr()
  h.eliminate_buf(bufpin.config.remove_with, bufnr)
end

--- Move a buffer one step to the left in the list of pinned buffers.
--- When no bufnr is provided, the current buf is attempted to be moved.
---@param bufnr integer?
function bufpin.move_to_left(bufnr)
  if #h.state.pinned_bufnrs == 0 then
    return
  end
  bufnr = bufnr or vim.fn.bufnr()
  local bufnr_index = h.table_find_index(h.state.pinned_bufnrs, bufnr)
  if bufnr_index ~= nil and bufnr_index > 1 then
    local swap = h.state.pinned_bufnrs[bufnr_index - 1]
    h.state.pinned_bufnrs[bufnr_index - 1] = bufnr
    h.state.pinned_bufnrs[bufnr_index] = swap
    bufpin.refresh_tabline()
  end
end

--- Move a buffer one step to the right in the list of pinned buffers.
--- When no bufnr is provided, the current buf is attempted to be moved.
---@param bufnr integer?
function bufpin.move_to_right(bufnr)
  if #h.state.pinned_bufnrs == 0 then
    return
  end
  bufnr = bufnr or vim.fn.bufnr()
  local bufnr_index = h.table_find_index(h.state.pinned_bufnrs, bufnr)
  if bufnr_index ~= nil and bufnr_index < #h.state.pinned_bufnrs then
    local swap = h.state.pinned_bufnrs[bufnr_index + 1]
    h.state.pinned_bufnrs[bufnr_index + 1] = bufnr
    h.state.pinned_bufnrs[bufnr_index] = swap
    bufpin.refresh_tabline()
  end
end

function bufpin.edit_left()
  if #h.state.pinned_bufnrs == 0 then
    return
  end
  local current_bufnr = vim.fn.bufnr()
  local bufnr_index = h.table_find_index(h.state.pinned_bufnrs, current_bufnr)
  if bufnr_index == nil then
    -- Ghost buf is active.
    vim.cmd("buffer " .. h.state.pinned_bufnrs[#h.state.pinned_bufnrs])
  elseif bufnr_index > 1 then
    vim.cmd("buffer " .. h.state.pinned_bufnrs[bufnr_index - 1])
    bufpin.refresh_tabline()
  elseif bufnr_index == 1 then
    -- Circular editing.
    if h.state.ghost_bufnr ~= nil then
      vim.cmd("buffer " .. h.state.ghost_bufnr)
    else
      vim.cmd("buffer " .. h.state.pinned_bufnrs[#h.state.pinned_bufnrs])
    end
    bufpin.refresh_tabline()
  end
end

function bufpin.edit_right()
  if #h.state.pinned_bufnrs == 0 then
    return
  end
  local bufnr_index = h.table_find_index(h.state.pinned_bufnrs, vim.fn.bufnr())
  if bufnr_index == nil then
    -- Ghost buf is active.
    vim.cmd("buffer " .. h.state.pinned_bufnrs[1])
  elseif bufnr_index < #h.state.pinned_bufnrs then
    vim.cmd("buffer " .. h.state.pinned_bufnrs[bufnr_index + 1])
    bufpin.refresh_tabline()
  elseif bufnr_index == #h.state.pinned_bufnrs then
    if h.state.ghost_bufnr ~= nil then
      vim.cmd("buffer " .. h.state.ghost_bufnr)
    else
      -- Circular editing.
      vim.cmd("buffer " .. h.state.pinned_bufnrs[1])
    end
    bufpin.refresh_tabline()
  end
end

---@param index integer Index of a pinned buf in |bufpin.get_pinned_bufs()|.
function bufpin.edit_by_index(index)
  if index <= #h.state.pinned_bufnrs then
    vim.cmd("buffer " .. h.state.pinned_bufnrs[index])
  elseif index == #h.state.pinned_bufnrs + 1 and h.state.ghost_bufnr ~= nil then
    vim.cmd("buffer " .. h.state.ghost_bufnr)
  end
  bufpin.refresh_tabline()
end

--- Get all the pinned bufs. This is the actual list, not a copy.
---@return integer[] Buf handlers.
function bufpin.get_pinned_bufs()
  return h.state.pinned_bufnrs
end

--- Set the option 'tabline'. The tabline is not drawn during a session
--- (|session-file|) load. To force draw send `force` as true.
---@param force boolean?
function bufpin.refresh_tabline(force)
  if vim.fn.exists("SessionLoad") == 1 and force ~= true then
    return
  end
  local tabline = ""
  h.prune_invalid_ghost_buf_from_state()
  h.prune_invalid_pinned_bufs_from_state()
  local pinned_bufs = h.normalize_pinned_bufs()
  tabline = tabline .. h.build_tabline(pinned_bufs)
  vim.o.tabline = tabline
  if bufpin.config.auto_hide_tabline then
    h.show_tabline()
  end
  h.serialize_state()
end

-- Set module default config.
h.assign_default_config()

-- -----
--- #end

-- Vimscript functions.
vim.cmd([[
function! BufpinTlOnClickBuf(minwid,clicks,button,modifiers)
  if a:clicks == 1
    if a:button == 'l'
      execute 'buffer' a:minwid
    elseif a:button == 'm'
      call v:lua.Bufpin.remove(a:minwid)
    endif
  endif
endfunction
]])

---@class PinnedBuf
---@field bufnr integer
---@field basename string
---@field differentiator string?
---@field selected boolean

---@class BufpinConfig
---@field auto_hide_tabline boolean
---@field set_default_keymaps boolean
---@field exclude fun(bufnr:integer): boolean
---@field exclude_runr_bufs boolean
---@field use_mini_bufremove boolean
---@field icons_style "color"|"monochrome"|"monochrome_selected"|"hidden"
---@field ghost_buf_enabled boolean
---@field remove_with "delete"|"wipeout"
---@field logging BufpinLoggingConfig

---@class BufpinLoggingConfig
---@field enabled boolean
---@field level 0|1|2|3|4|5

--- Merge user-supplied config with the plugin's default config. For every key
--- which is not supplied by the user, the value in the default config will be
--- used. The user's config has precedence; the default config is the fallback.
---@param config? table User supplied config.
---@param default_config table Fallback config.
---@return BufpinConfig
function h.get_config_with_fallback(config, default_config)
  vim.validate("config", config, "table", true)
  config =
    vim.tbl_deep_extend("force", vim.deepcopy(default_config), config or {})
  vim.validate("config.auto_hide_tabline", config.auto_hide_tabline, "boolean")
  vim.validate(
    "config.set_default_keymaps",
    config.set_default_keymaps,
    "boolean"
  )
  vim.validate("config.exclude", config.exclude, "function")
  vim.validate("config.use_mini_bufremove", config.use_mini_bufremove, "boolean")
  vim.validate("config.icons_style", config.icons_style, "string")
  vim.validate("config.ghost_buf_enabled", config.ghost_buf_enabled, "boolean")
  vim.validate("config.remove_with", config.remove_with, "string")
  vim.validate("config.logging.enabled", config.logging.enabled, "boolean")
  vim.validate("config.logging.level", config.logging.level, "number")
  return config
end

---@return boolean
function h.should_use_mini_bufremove()
  return bufpin.config.use_mini_bufremove and h.has_mini_bufremove()
end

--- For session persistence. Store state in `vim.g.BufpinState`. Deserialize in
--- the autocmd event `SessionLoadPost.` In `pinned_bufs`, full file names are
--- serialized. Note: Neovim has no `SessionWritePre` event:
--- <https://github.com/neovim/neovim/issues/22814>.
function h.serialize_state()
  local state = {
    pinned_buf_names = vim
      .iter(h.state.pinned_bufnrs)
      :filter(function(bufnr)
        return vim.fn.bufexists(bufnr) == 1
      end)
      :map(function(bufnr)
        return vim.api.nvim_buf_get_name(bufnr)
      end)
      :totable(),
  }
  if
    bufpin.config.ghost_buf_enabled
    and h.state.ghost_bufnr ~= nil
    and vim.fn.bufexists(h.state.ghost_bufnr) == 1
  then
    state.ghost_buf_name = vim.api.nvim_buf_get_name(h.state.ghost_bufnr)
  end
  vim.g.BufpinState = vim.json.encode(state)
end

--- Delete or wipeout a buf. Conditionally use mini.bufremove.
---@param operation "delete"|"wipeout"
---@param bufnr integer
function h.eliminate_buf(operation, bufnr)
  if vim.bo[bufnr].modified then
    if h.should_use_mini_bufremove() then
      require("mini.bufremove")[operation](bufnr)
    else
      vim.cmd(bufnr .. "b" .. operation)
    end
  else
    if h.should_use_mini_bufremove() then
      bufpin.unpin(bufnr)
      if h.state.ghost_bufnr == bufnr then
        h.state.ghost_bufnr = nil
      end
      require("mini.bufremove")[operation](bufnr)
    else
      bufpin.unpin(bufnr)
      if h.state.ghost_bufnr == bufnr then
        h.state.ghost_bufnr = nil
      end
      vim.cmd(bufnr .. "b" .. operation)
    end
  end
  bufpin.refresh_tabline()
end

---@param pinned_buf PinnedBuf
---@return string
function h.build_tabline_pinned_buf(pinned_buf)
  local basename = pinned_buf.basename
  if pinned_buf.differentiator ~= nil then
    basename = pinned_buf.differentiator .. "/" .. basename
  end
  if pinned_buf.selected then
    return "%"
      .. pinned_buf.bufnr
      .. "@BufpinTlOnClickBuf@"
      .. "%#"
      .. h.const.HL_BUFPIN_TAB_LINE_SEL
      .. "#  "
      .. h.get_icon_string_for_tabline_buf(basename, true, false)
      .. basename
      .. "  %*"
      .. "%X"
  else
    return "%"
      .. pinned_buf.bufnr
      .. "@BufpinTlOnClickBuf@"
      .. "%#"
      .. h.const.HL_BUFPIN_TAB_LINE_FILL
      .. "#  "
      .. h.get_icon_string_for_tabline_buf(basename, false, false)
      .. basename
      .. "  %*"
      .. "%X"
  end
end

---@return string
function h.build_tabline_ghost_buf()
  local ghost_buf = h.state.ghost_bufnr
  if ghost_buf == nil then
    return ""
  end
  local ghost_buf_is_selected = ghost_buf == vim.fn.bufnr()
  local hl = h.const.HL_BUFPIN_GHOST_TAB_LINE_FILL
  if ghost_buf_is_selected then
    hl = h.const.HL_BUFPIN_GHOST_TAB_LINE_SEL
  end
  local basename = vim.fs.basename(vim.api.nvim_buf_get_name(ghost_buf))
  return "%"
    .. ghost_buf
    .. "@BufpinTlOnClickBuf@"
    .. "%#"
    .. hl
    .. "#  "
    .. h.get_icon_string_for_tabline_buf(basename, ghost_buf_is_selected, true)
    .. basename
    .. "  %*"
    .. "%X"
end

---@param buf_name string
---@param buf_is_selected boolean
---@param is_ghost_buf boolean
function h.get_icon_string_for_tabline_buf(
  buf_name,
  buf_is_selected,
  is_ghost_buf
)
  local has_mini_icons = h.has_mini_icons()
  if not has_mini_icons or bufpin.config.icons_style == "hidden" then
    return ""
  end
  local bufpin_icon_hl = nil
  local icon, icon_hl = nil, nil
  if has_mini_icons then
    ---@diagnostic disable-next-line: undefined-global
    icon, icon_hl = MiniIcons.get("file", buf_name)
    bufpin_icon_hl = "Bufpin"
      .. (buf_is_selected and "Sel" or "Fill")
      .. (is_ghost_buf and "Ghost" or "")
      .. icon_hl
    if
      vim.tbl_contains({
        "color",
        "monochrome_selected",
      }, bufpin.config.icons_style)
    then
      if h.state.hl_cache[bufpin_icon_hl] == nil then
        local hl = {
          bg = h.get_icon_hi_bg(buf_is_selected, is_ghost_buf),
          fg = h.get_hl(icon_hl).fg,
        }
        vim.api.nvim_set_hl(0, bufpin_icon_hl, hl)
        h.state.hl_cache[bufpin_icon_hl] = hl
      end
    end
  end
  local icon_string = ""
  local hl_buf_selected = h.const.HL_BUFPIN_TAB_LINE_SEL
  if is_ghost_buf then
    hl_buf_selected = h.const.HL_BUFPIN_GHOST_TAB_LINE_SEL
  end
  local hl_buf_fill = h.const.HL_BUFPIN_TAB_LINE_FILL
  if is_ghost_buf then
    hl_buf_fill = h.const.HL_BUFPIN_GHOST_TAB_LINE_FILL
  end
  if buf_is_selected then
    if has_mini_icons then
      if bufpin.config.icons_style == "color" then
        icon_string = "%#"
          .. bufpin_icon_hl
          .. "#"
          .. icon
          .. "%*%#"
          .. hl_buf_selected
          .. "# "
      elseif
        bufpin.config.icons_style == "monochrome"
        or bufpin.config.icons_style == "monochrome_selected"
      then
        icon_string = icon .. " "
      end
    end
  else
    if has_mini_icons then
      if
        bufpin.config.icons_style == "color"
        or bufpin.config.icons_style == "monochrome_selected"
      then
        icon_string = "%#"
          .. bufpin_icon_hl
          .. "#"
          .. icon
          .. "%*%#"
          .. hl_buf_fill
          .. "# "
      elseif bufpin.config.icons_style == "monochrome" then
        icon_string = icon .. " "
      end
    end
  end
  return icon_string
end

---@param buf_is_selected boolean
---@param is_ghost_buf boolean
---@return integer
function h.get_icon_hi_bg(buf_is_selected, is_ghost_buf)
  if buf_is_selected and not is_ghost_buf then
    return h.get_hl(h.const.HL_BUFPIN_TAB_LINE_SEL).bg
  end
  if not buf_is_selected and not is_ghost_buf then
    return h.get_hl(h.const.HL_BUFPIN_TAB_LINE_FILL).bg
  end
  if buf_is_selected and is_ghost_buf then
    return h.get_hl(h.const.HL_BUFPIN_GHOST_TAB_LINE_SEL).bg
  end
  if not buf_is_selected and is_ghost_buf then
    return h.get_hl(h.const.HL_BUFPIN_GHOST_TAB_LINE_FILL).bg
  end
  error("Invalid state: Highlight group not found")
end

--- Get highlight group. Follows links.
---@param hl_name string
---@return vim.api.keyset.get_hl_info
function h.get_hl(hl_name)
  local hl = vim.api.nvim_get_hl(0, {
    name = hl_name,
    create = false,
  })
  while type(hl.link) == "string" do
    hl = vim.api.nvim_get_hl(0, {
      name = hl.link,
      create = false,
    })
  end
  return hl
end

--- Prune with `h.prune_nonexistent_bufs_from_state` before calling this function.
---@param pinned_bufs PinnedBuf[]
---@return string
function h.build_tabline(pinned_bufs)
  local tabline = ""
  for _, pinned_buf in ipairs(pinned_bufs) do
    tabline = tabline .. h.build_tabline_pinned_buf(pinned_buf)
  end
  if h.should_include_ghost_buf() then
    tabline = tabline .. h.build_tabline_ghost_buf()
  end
  return tabline .. "%#" .. h.const.HL_BUFPIN_TAB_LINE_FILL .. "#"
end

---@return boolean
function h.should_include_ghost_buf()
  if
    h.state.ghost_bufnr ~= nil
    and vim.bo[h.state.ghost_bufnr].buftype == "help"
  then
    -- For some reason uknown to me, help files need special handling.
    h.state.ghost_bufnr = nil
    return false
  end
  if not bufpin.config.ghost_buf_enabled then
    return false
  end
  local current_bufnr = vim.fn.bufnr()
  if
    vim.tbl_contains(h.state.pinned_bufnrs, current_bufnr)
    and h.state.ghost_bufnr == nil
  then
    -- Current buf is pinned and there is no ghost buf.
    return false
  end
  return true
end

--- Don't override existing hl definitions.
function h.set_hl_defaults()
  local hsluv = require("bufpin.hsluv")
  local hl_status_line = h.get_hl("StatusLine")
  h.log(function()
    return vim.fn.execute("verbose hi StatusLine")
  end)
  local hl_bufpin_tab_line_sel = hl_status_line
  vim.api.nvim_set_hl(0, h.const.HL_BUFPIN_TAB_LINE_SEL, {
    fg = hl_bufpin_tab_line_sel.fg,
    bg = hl_bufpin_tab_line_sel.bg,
    reverse = hl_bufpin_tab_line_sel.reverse,
    default = true,
  })
  vim.api.nvim_set_hl(0, h.const.HL_BUFPIN_GHOST_TAB_LINE_SEL, {
    fg = hl_bufpin_tab_line_sel.fg,
    bg = hl_bufpin_tab_line_sel.bg,
    reverse = hl_bufpin_tab_line_sel.reverse,
    italic = true,
    default = true,
  })
  local hl_normal = h.get_hl("Normal")
  h.log(function()
    return vim.fn.execute("verbose hi Normal")
  end)
  local hsluv_normal_bg = hsluv.hex_to_hsluv("#" .. bit.tohex(hl_normal.bg, 6))
  local hl_normal_bg_adjusted = hsluv.hsluv_to_hex({
    hsluv_normal_bg[1],
    hsluv_normal_bg[2],
    (vim.o.background == "light" and 90 or 20),
  })
  local hl_bufpin_tab_line_fill = {
    fg = hl_normal.fg,
    bg = hl_normal_bg_adjusted,
    reverse = hl_normal.reverse,
  }
  vim.api.nvim_set_hl(0, h.const.HL_BUFPIN_TAB_LINE_FILL, {
    fg = hl_bufpin_tab_line_fill.fg,
    bg = hl_bufpin_tab_line_fill.bg,
    reverse = hl_bufpin_tab_line_fill.reverse,
    default = true,
  })
  vim.api.nvim_set_hl(0, h.const.HL_BUFPIN_GHOST_TAB_LINE_FILL, {
    fg = hl_bufpin_tab_line_fill.fg,
    bg = hl_bufpin_tab_line_fill.bg,
    reverse = hl_bufpin_tab_line_fill.reverse,
    italic = true,
    default = true,
  })
end

--- Find the index of a value in a list-like table.
---@param tbl table Numerically indexed table (list).
---@param target_value any The value being searched in `tbl`.
---@return integer? Index or nil if the item was not found.
function h.table_find_index(tbl, target_value)
  local index = nil
  for i, tbl_value in ipairs(tbl) do
    if target_value == tbl_value then
      index = i
      break
    end
  end
  return index
end

---@param bufnr integer
---@return boolean
function h.is_plugin_buf(bufnr)
  local no_name_filetypes = { nil, "" }
  local matched_filetype, _ = vim.filetype.match({ buf = bufnr })
  return matched_filetype == nil
    and not vim.bo.buflisted
    and not vim.tbl_contains(no_name_filetypes, vim.bo[bufnr].filetype)
end

---@param win_id integer
---@return boolean
function h.is_floating_win(win_id)
  -- See |api-floatwin| to learn how to check whether a win is floating.
  return vim.api.nvim_win_get_config(win_id).relative ~= ""
end

function h.prune_invalid_pinned_bufs_from_state()
  h.state.pinned_bufnrs = vim
    .iter(h.state.pinned_bufnrs)
    :filter(function(bufnr)
      return vim.fn.bufexists(bufnr) == 1
    end)
    :totable()
end

function h.prune_invalid_ghost_buf_from_state()
  if
    vim.tbl_contains(h.state.pinned_bufnrs, h.state.ghost_bufnr)
    or vim.fn.bufexists(h.state.ghost_bufnr) == 0
  then
    h.state.ghost_bufnr = nil
  end
end

---@param bufnr integer
function h.pin_by_bufnr(bufnr)
  local bufnr_index = h.table_find_index(h.state.pinned_bufnrs, bufnr)
  if bufnr_index == nil then
    table.insert(h.state.pinned_bufnrs, bufnr)
  end
end

---@param bufnr integer
function h.unpin_by_bufnr(bufnr)
  local bufnr_index = h.table_find_index(h.state.pinned_bufnrs, bufnr)
  if bufnr_index ~= nil then
    table.remove(h.state.pinned_bufnrs, bufnr_index)
  end
end

--- Show the tabline only when there is a pinned buf to show.
function h.show_tabline()
  if #h.state.pinned_bufnrs > 0 then
    vim.o.showtabline = 2
  else
    vim.o.showtabline = 0
  end
end

function h.print_user_error(message)
  vim.api.nvim_echo({ { message, "Error" } }, true, {})
end

-- TODO: Consider ghost buf to differentiate repeating basenames in tabline.

---@return integer[]
function h.get_bufnrs_with_repeating_basename()
  local basenames_count = {}
  local bufs_with_repeating_basename = {}
  for _, pinned_buf in ipairs(h.state.pinned_bufnrs) do
    local basename = vim.fs.basename(vim.api.nvim_buf_get_name(pinned_buf))
    if basenames_count[basename] == nil then
      basenames_count[basename] = 1
    else
      basenames_count[basename] = basenames_count[basename] + 1
    end
  end
  for _, pinned_buf in ipairs(h.state.pinned_bufnrs) do
    local basename = vim.fs.basename(vim.api.nvim_buf_get_name(pinned_buf))
    if basenames_count[basename] > 1 then
      table.insert(bufs_with_repeating_basename, pinned_buf)
    end
  end
  return bufs_with_repeating_basename
end

---@return PinnedBuf[]
function h.normalize_pinned_bufs()
  local pinned_bufnrs = {}
  local current_bufnr = vim.fn.bufnr()
  local bufnrs_with_repeating_basename = h.get_bufnrs_with_repeating_basename()
  for _, bufnr in ipairs(h.state.pinned_bufnrs) do
    local full_filename = vim.api.nvim_buf_get_name(bufnr)
    if vim.tbl_contains(bufnrs_with_repeating_basename, bufnr) then
      -- Set differentiator when >1 pinned bufs have the same basename. Use always
      -- the parent directory to attempt to differentiate. This strategy ignores
      -- the rare case of different parent dirs having the same name.
      local parent_dir = vim.fn.fnamemodify(full_filename, ":h:t")
      if vim.fn.fnamemodify(full_filename, ":h") == vim.uv.cwd() then
        parent_dir = "."
      end
      table.insert(pinned_bufnrs, {
        bufnr = bufnr,
        basename = vim.fs.basename(full_filename),
        selected = current_bufnr == bufnr,
        differentiator = parent_dir,
      })
    else
      table.insert(pinned_bufnrs, {
        bufnr = bufnr,
        basename = vim.fs.basename(full_filename),
        selected = current_bufnr == bufnr,
      })
    end
  end
  return pinned_bufnrs
end

---@param bufnr integer
---@return boolean
function h.is_runr_buf(bufnr)
  if h.has_runr() and bufpin.config.exclude_runr_bufs then
    return require("runr").is_runr_file_loaded(bufnr)
  else
    return false
  end
end

---@param bufnr integer
---@return boolean
function h.should_exclude_from_pin(bufnr)
  return bufpin.config.exclude(bufnr)
    or vim.api.nvim_buf_get_name(bufnr) == ""
    or vim.bo[bufnr].buftype == "quickfix"
    or vim.bo[bufnr].buftype == "nofile"
    or vim.bo[bufnr].buftype == "help"
    or h.is_plugin_buf(bufnr)
    or h.is_runr_buf(bufnr)
    or h.is_floating_win(0)
end

h.bufpin_augroup = vim.api.nvim_create_augroup("PinAugroup", {})

h.state = {
  hl_cache = {},
  pinned_bufnrs = {},
  -- Approach for managing the state of ghost_bufnr: Set in an autocmd, then set
  -- to nil (or rearely to another buf) on a case-by-case basis per API function.
  ghost_bufnr = nil,
  log_filepath = vim.fn.stdpath("log") .. "/bufpin.log",
}

h.const = {
  HL_BUFPIN_TAB_LINE_SEL = "BufpinTabLineSel",
  HL_BUFPIN_TAB_LINE_FILL = "BufpinTabLineFill",
  HL_BUFPIN_GHOST_TAB_LINE_SEL = "BufpinGhostTabLineSel",
  HL_BUFPIN_GHOST_TAB_LINE_FILL = "BufpinGhostTabLineFill",
}

-- Useful to debug.

function bufpin._get_state()
  return h.state
end

function bufpin._get_h()
  return h
end

---@param level integer As per |vim.log.levels|.
function h.should_log(level)
  return bufpin.config.logging.enabled and level >= bufpin.config.logging.level
end

--- Returns true when mini.icons is installed:
--- <https://github.com/nvim-mini/mini.icons>.
---@return boolean
function h.has_mini_icons()
  return package.loaded["mini.icons"] ~= nil
end

--- Returns true when mini.bufremove is installed:
--- <https://github.com/nvim-mini/mini.bufremove>.
---@return boolean
function h.has_mini_bufremove()
  return package.loaded["mini.bufremove"] ~= nil
end

--- Returns true when runr.nvim is installed:
--- <https://github.com/hernancerm/runr.nvim>.
---@return boolean
function h.has_runr()
  return package.loaded["runr"] ~= nil
end

---@param message string|fun():string Use function type for expensive operations.
---@param level integer? As per |vim.log.levels|.
function h.log(message, level)
  level = level or vim.log.levels.INFO
  if not h.should_log(level) then
    return
  end
  if type(message) == "function" then
    message = message()
  end
  vim.defer_fn(function()
    vim.fn.writefile({
      string.format(
        "%s %s - %s\n",
        vim.fn.get({ "D", "I", "W", "E" }, level - 1),
        vim.fn.strftime("%H:%M:%S"),
        message
      ),
    }, h.state.log_filepath, "a")
  end, 0)
end

return bufpin
