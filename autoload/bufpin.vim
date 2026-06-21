function! bufpin#_on_click_buffer(minwid, clicks, button, modifiers)
  if a:clicks == 1
    if a:button == 'l'
      execute 'buffer' a:minwid
    elseif a:button == 'm'
      call v:lua.Bufpin.remove(a:minwid)
    endif
  endif
endfunction

function! bufpin#_on_click_tabpage(minwid, clicks, button, modifiers)
  if a:clicks == 1
    if a:button == 'l'
      call nvim_set_current_tabpage(a:minwid)
    elseif a:button == 'm'
      let tabnr = nvim_tabpage_get_number(a:minwid)
      execute l:tabnr 'tabclose'
    endif
  endif
endfunction
