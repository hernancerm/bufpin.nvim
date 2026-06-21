function! bufpin#_on_click_buf(minwid, clicks, button, modifiers)
  if a:clicks == 1
    if a:button == 'l'
      execute 'buffer' a:minwid
    elseif a:button == 'm'
      call v:lua.Bufpin.remove(a:minwid)
    endif
  endif
endfunction
