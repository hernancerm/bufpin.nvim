--- *bufpin* Pin buffers for quick navigation.
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
--- Problem:
---
--- From https://github.com/ThePrimeagen/harpoon/tree/harpoon2:
--- >text
---   You're working on a codebase. medium, large, tiny, whatever. You find
---   yourself frequenting a small set of files and you are tired of using a fuzzy
---   finder, :bnext & :bprev are getting too repetitive, alternate file doesn't
---   quite cut it, etc etc.
--- <
--- Solution:
---
--- Pin buffers and allow navigating to them via keymaps. The pinned bufs are
--- drawn in the 'tabline'. Visually, this looks like tabs in a modern text
--- editor, but the distinction is that the bufs are all manually tracked.
---
--- Quickstart:
---
--- Install the plugin with your favorite package manager, then set these keymaps:
--- >lua
---   local opts = { silent = true }
---   vim.keymap.set("n", "<Leader>p", ":lua Bufpin.toggle()<CR>",         opts)
---   vim.keymap.set("n", "<Leader>w", ":lua Bufpin.remove()<CR>",         opts)
---   vim.keymap.set("n", "<Up>",      ":lua Bufpin.edit_left()<CR>",      opts)
---   vim.keymap.set("n", "<Down>",    ":lua Bufpin.edit_right()<CR>",     opts)
---   vim.keymap.set("n", "<Left>",    ":lua Bufpin.move_to_left()<CR>",   opts)
---   vim.keymap.set("n", "<Right>",   ":lua Bufpin.move_to_right()<CR>",  opts)
---   vim.keymap.set("n", "<F1>",      ":lua Bufpin.edit_by_index(1)<CR>", opts)
---   vim.keymap.set("n", "<F2>",      ":lua Bufpin.edit_by_index(2)<CR>", opts)
---   vim.keymap.set("n", "<F3>",      ":lua Bufpin.edit_by_index(3)<CR>", opts)
---   vim.keymap.set("n", "<F4>",      ":lua Bufpin.edit_by_index(4)<CR>", opts)
--- <
--- Some things to notice:
---
--- * No need to call |bufpin.setup()|, but you may do so to configure the plugin.
--- * The plugin sets the Lua global `Bufpin`, equivalent to `require("bufpin")`.
--- * The plugin doesn't create keymaps, you need to define them yourself.
---
--- With the keymaps above you may try:
---
--- 1. |:edit| an existent file.
--- 2. Press <Leader>p to pin the buffer. See the buffer is shown in the tabline.
--- 3. Press <Leader>p on other files to pin them as well.
--- 4. Re-order the pinned bufs with <Left> and <Right>.
--- 5. Cycle through pinned bufs with <Up> and <Down>.
--- 6. Press <Leader>w to unpin a buf.

local bufpin = {}

_G.Bufpin = bufpin

vim.api.nvim_create_augroup("Bufpin", { clear = true })

--- #delimiter
--- #tag bufpin.config
--- #tag bufpin.default_config
--- #tag bufpin-configuration
--- Configuration ~

--- The effective config (defaults with overrides) is in `require("bufpin").config`,
--- which is set by |bufpin.setup()|. The default config remains constant and is in
--- `require("bufpin").default_config`, for reference.

--- Module setup.
--- Sets `require("bufpin").config`.
---@param config table?
function bufpin.setup(config)
  config = config or {}
  -- Merged default and user configuration. User configuration has precedence.
  bufpin.config = vim.tbl_deep_extend(
    "force",
    vim.deepcopy(bufpin.config or bufpin.default_config),
    config
  )
  -- Validate config.
  -- Validating merged config to avoid nil keys.
  vim.validate(
    "bufpin.config.auto_hide_tabline",
    bufpin.config.auto_hide_tabline,
    "boolean"
  )
  vim.validate("bufpin.config.exclude", bufpin.config.exclude, "function")
  vim.validate(
    "bufpin.config.use_mini_bufremove",
    bufpin.config.use_mini_bufremove,
    "boolean"
  )
  vim.validate("bufpin.config.icons_style", bufpin.config.icons_style, "string")
  vim.validate(
    "bufpin.config.sticky_remove_enabled",
    bufpin.config.sticky_remove_enabled,
    "boolean"
  )
  vim.validate(
    "bufpin.config.mouse_drag_reorder",
    bufpin.config.mouse_drag_reorder,
    "boolean"
  )
  vim.validate(
    "bufpin.config.ghost_buf_enabled",
    bufpin.config.ghost_buf_enabled,
    "boolean"
  )
  vim.validate("bufpin.config.remove_with", bufpin.config.remove_with, "string")
end

--- Default config:
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)

bufpin.default_config = {
  auto_hide_tabline = true,
  exclude = function(_) end,
  use_mini_bufremove = true,
  icons_style = "monochrome_selected",
  sticky_remove_enabled = true,
  mouse_drag_reorder = false,
  ghost_buf_enabled = true,
  remove_with = "delete",
}
--minidoc_afterlines_end

--- #tag bufpin.config.auto_hide_tabline
--- `(boolean)`
--- When true and there are no pinned bufs, hide the tabline.

--- #tag bufpin.config.exclude
--- `(fun(bufnr:integer):boolean)`
--- When the function returns true, the buf (`bufnr`) is ignored. This means that
--- the buf is not displayed in the tabline and calling |bufpin.pin()| on it has
--- no effect. Some bufs are excluded regardless of this opt: bufs without a
--- name ([No Name]), Vim help files, man pages, detected plugin bufs (e.g.,
--- nvimtree) and floating wins.

--- #tag bufpin.config.use_mini_bufremove
--- `(boolean)`
--- You need to have installed <https://github.com/echasnovski/mini.bufremove>.
--- When true, all buf deletions and wipeouts are done via the `mini.bufremove`
--- plugin, thus preserving window layouts.

--- #tag bufpin.config.mouse_drag_reorder
--- `(boolean)`
--- When true, allow re-ordering both the pinned bufs and the vim tabpages by
--- mouse-dragging them in the tabline.

--- #tag bufpin.config.icons_style
--- `("color"|"monochrome"|"monochrome_selected"|"hidden")`
--- You need to have installed <https://github.com/nvim-mini/mini.icons>. Use
--- `monochrome_selected` to display only the selected buf's file type icon as
--- monochrome, the other icons are colored. Use `hidden` to not display icons
--- altogether.

--- #tag.bufpin.config.sticky_remove_enabled
--- `(boolean)`
--- Affects |bufpin.remove()|. When false, the function removes the buf as per
--- the opt |bufpin.config.remove_with|, that's it. When true, in addition to the
--- buf removal, the new focused buf is the last one visited that is tracked by
--- bufpin (either a pinned buf or the ghost buf). When none of them has been
--- visited yet, as right after a session load, the new focused buf is the
--- neighbor in the tabline of the removed buf.
---
--- The motivation of this opt is to simulate that only the bufs drawn in the
--- tabline exist without actually deleting or wiping out the other bufs. This
--- prevents consecutive ghost bufs appearing on ghost buf removal.

--- #tag bufpin.config.ghost_buf_enabled
--- `(boolean)`
--- Whether to display the ghost buf, i.e., the last visited non-pinned pin-able
--- buf. If any, it's displayed always as the last item in the tabline. This buf
--- is tracked by the plugin regardless of this opt, this opt only controls its
--- visibility in the tabline.

--- #tag bufpin.config.remove_with
--- `("delete"|"wipeout")`
--- Set how buf removal is done for both the function |bufpin.remove()| and the
--- mouse middle click input on a buf in the tabline.

--- #delimiter
--- #tag bufpin-highlight-groups
--- Highlight groups ~
---
--- * `BufpinTabLineSel`: Selected pinned buffer.
--- * `BufpinGhostTabLineSel`: Selected ghost buffer.
--- * `BufpinTabLine`: Unselected pinned buffer.
--- * `BufpinTabLineFill`: Tabline background.

--- #delimiter
--- #tag bufpin-functions
--- Functions ~

--- Pin the current buf or the provided buf.
---@param bufnr integer?
function bufpin.pin(bufnr)
  local h = require("bufpin.helpers")
  local current_bufnr = vim.fn.bufnr()
  bufnr = bufnr or current_bufnr
  if h.should_exclude_from_pin(bufnr, bufpin.config.exclude) then
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
  local h = require("bufpin.helpers")
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
  local h = require("bufpin.helpers")
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
  bufnr = (not bufnr or bufnr == 0) and vim.fn.bufnr() or bufnr
  local h = require("bufpin.helpers")

  local force = vim.bo[bufnr].modified
  if force then
    local prompt = "Buf " .. bufnr .. " has unsaved changes. Remove anyway?"
    if vim.fn.confirm(prompt, "&No\n&Yes", 1, "Question") ~= 2 then
      return
    end
  end

  local sticky_bufnr = nil
  if
    bufpin.config.sticky_remove_enabled
    and bufnr == vim.fn.bufnr()
    and h.is_tracked_buf(bufnr)
  then
    sticky_bufnr = h.sticky_buf(bufnr, bufpin.config.ghost_buf_enabled)
  end

  if sticky_bufnr then
    vim.cmd.buffer(sticky_bufnr)
  end

  local operation = bufpin.config.remove_with
  if h.should_use_mini_bufremove(bufpin.config.use_mini_bufremove) then
    require("mini.bufremove")[operation](bufnr, force)
  else
    vim.cmd(bufnr .. "b" .. operation .. (force and "!" or ""))
  end
  bufpin.refresh_tabline()
end

--- Move a buffer one step to the left in the list of pinned buffers.
--- When no bufnr is provided, the current buf is attempted to be moved.
---@param bufnr integer?
function bufpin.move_to_left(bufnr)
  local h = require("bufpin.helpers")
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
  local h = require("bufpin.helpers")
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

--- Edit the buf to the left in the tabline, wrapping around at the left edge.
function bufpin.edit_left()
  local h = require("bufpin.helpers")
  if #h.state.pinned_bufnrs == 0 then
    return
  end
  local tracked_bufnrs = h.get_tabline_bufs(bufpin.config.ghost_buf_enabled)
  local index = h.table_find_index(tracked_bufnrs, vim.fn.bufnr())
  -- A nil index means the current buf is not drawn in the tabline, e.g. a help
  -- file, in which case entering the tabline from its right edge reads best.
  local target_bufnr = tracked_bufnrs[#tracked_bufnrs]
  if index ~= nil then
    target_bufnr = tracked_bufnrs[index - 1] or tracked_bufnrs[#tracked_bufnrs]
  end
  vim.cmd("buffer " .. target_bufnr)
  bufpin.refresh_tabline()
end

--- Edit the buf to the right in the tabline, wrapping around at the right edge.
function bufpin.edit_right()
  local h = require("bufpin.helpers")
  if #h.state.pinned_bufnrs == 0 then
    return
  end
  local tracked_bufnrs = h.get_tabline_bufs(bufpin.config.ghost_buf_enabled)
  local index = h.table_find_index(tracked_bufnrs, vim.fn.bufnr())
  -- As in |bufpin.edit_left()|, but entering from the left edge.
  local target_bufnr = tracked_bufnrs[1]
  if index ~= nil then
    target_bufnr = tracked_bufnrs[index + 1] or tracked_bufnrs[1]
  end
  vim.cmd("buffer " .. target_bufnr)
  bufpin.refresh_tabline()
end

---@param index integer Index of a buf as drawn in the tabline, i.e., the pinned
--- bufs in the order of |bufpin.get_pinned_bufs()| followed by the ghost buf.
function bufpin.edit_by_index(index)
  local h = require("bufpin.helpers")
  local tracked_bufnrs = h.get_tabline_bufs(bufpin.config.ghost_buf_enabled)
  if tracked_bufnrs[index] ~= nil then
    vim.cmd("buffer " .. tracked_bufnrs[index])
  end
  bufpin.refresh_tabline()
end

--- Get all the pinned bufs. This is a copy, so mutating it does not change the
--- pin state. Use |bufpin.pin()| and |bufpin.unpin()| for that.
---@return integer[]
function bufpin.get_pinned_bufs()
  return vim.deepcopy(require("bufpin.helpers").state.pinned_bufnrs)
end

--- Get the bufs of the tabline (pinned bufs, then ghost buf), in the order they
--- are drawn. All of them, including those hidden when the tabline overflows.
--- This is a copy. Respects |bufpin.config.ghost_buf_enabled|.
---@return integer[]
function bufpin.get_tabline_bufs()
  return require("bufpin.helpers").get_tabline_bufs(
    bufpin.config.ghost_buf_enabled
  )
end

--- Get the ghost buf. Disregards |bufpin.config.ghost_buf_enabled|.
---@return integer
function bufpin.get_ghost_buf()
  return require("bufpin.helpers").state.ghost_bufnr
end

--- Set the option 'tabline'. The tabline is not drawn during a session
--- (|session-file|) load. To force draw send `force` as true.
---@param force boolean?
function bufpin.refresh_tabline(force)
  local h = require("bufpin.helpers")
  if vim.fn.exists("SessionLoad") == 1 and force ~= true then
    return
  end
  local tabline = ""
  h.prune_invalid_ghost_buf_from_state()
  h.prune_invalid_pinned_bufs_from_state()
  h.prune_invalid_visit_order_from_state()
  local pinned_bufs = h.normalize_pinned_bufs()
  tabline = tabline
    .. h.build_tabline(
      pinned_bufs,
      bufpin.config.icons_style,
      bufpin.config.ghost_buf_enabled
    )
  vim.o.tabline = tabline
  if bufpin.config.auto_hide_tabline then
    h.show_tabline()
  end
  h.serialize_state(bufpin.config.ghost_buf_enabled)
end

-- The order of the definition of the autocmds is important. When autocmds have
-- the same event, the autocmds defined first are executed first.

-- Remove bufs from state.
vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
  group = "Bufpin",
  callback = function(event)
    local h = require("bufpin.helpers")
    local bufnr_index = h.table_find_index(h.state.pinned_bufnrs, event.buf)
    if bufnr_index ~= nil then
      table.remove(h.state.pinned_bufnrs, bufnr_index)
    end
    if h.state.ghost_bufnr == event.buf then
      h.state.ghost_bufnr = nil
    end
    h.state.visit_order[event.buf] = nil
  end,
})

-- Track visit order for sticky removal.
vim.api.nvim_create_autocmd("BufEnter", {
  group = "Bufpin",
  callback = function()
    local h = require("bufpin.helpers")
    h.state.visit_count = h.state.visit_count + 1
    h.state.visit_order[vim.fn.bufnr()] = h.state.visit_count
  end,
})

-- Do 2 things:
-- 1. Redraw the tabline when switching bufs and wins.
-- 2. Keep accurate the value of `h.state.ghost_bufnr`.
vim.api.nvim_create_autocmd({
  "BufEnter",
  "CmdlineLeave",
  "FocusGained",
  "VimResume",
  "VimResized",
  "TermLeave",
  "WinEnter",
  "TabNew",
  "TabClosed",
}, {
  group = "Bufpin",
  callback = function()
    local h = require("bufpin.helpers")
    local current_bufnr = vim.fn.bufnr()
    if
      not vim.tbl_contains(h.state.pinned_bufnrs, current_bufnr)
      and not h.should_exclude_from_pin(current_bufnr, bufpin.config.exclude)
    then
      h.state.ghost_bufnr = current_bufnr
    end
    -- Use `vim.schedule()` to cover case of `:tabmove`, so refresh happens after
    -- the effect of the command.
    vim.schedule(function()
      bufpin.refresh_tabline()
    end)
  end,
})

-- Set highlight groups.
-- From my testing ColorScheme is also executed when setting 'bg'.
vim.api.nvim_create_autocmd({ "UIEnter", "ColorScheme" }, {
  group = "Bufpin",
  callback = function()
    local h = require("bufpin.helpers")
    h.state.hl_cache = {}
    h.set_hl_defaults()
    bufpin.refresh_tabline()
  end,
})

-- Fix no selected buf in tabline when using blink.cmp's completion menu.
vim.api.nvim_create_autocmd("User", {
  group = "Bufpin",
  pattern = "BlinkCmpMenuOpen",
  callback = bufpin.refresh_tabline,
})

-- Re-build state from session.
vim.api.nvim_create_autocmd("SessionLoadPost", {
  group = "Bufpin",
  callback = function()
    local h = require("bufpin.helpers")
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

return bufpin
