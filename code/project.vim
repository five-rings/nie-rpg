
let t:title = 'nie'
let t:project = expand('<sfile>:p')
let t:project_path = fnamemodify(t:project, ':h')

" change director only at first time to be loaded if you use tabpage.vim
execute 'cd ' . expand('<sfile>:p:h')

function! s:set_make_env()
  set makeprg=buildrun.bat
  set errorformat&
  set errorformat+=%DEntering\ directory\ %f
  set suffixesadd=.rb
  set path&
  let &path .= ',' . t:project_path . '/script'
  let &path .= ',' . t:project_path . '/layout'
  set tags&
  let &tags .= ',' . t:project_path . '/script/tags'
  let $PATH = g:env_path . ';' . fnamemodify(t:project_path . '/../tool/bat', ':p')
endfunction
call s:set_make_env()

let t:build_commands = [
  \   '-f\\ debug ',
  \   '-f\\ release ',
  \   '-f\\ debug,pry\\ -i console',
  \   '-f\\ debug,test',
  \   '-f\\ debug,benchmark\\ -i',
  \ ]

function! s:reset_build_command()
  let t:build_command_index = len(t:build_commands)
endfunction
call s:reset_build_command()

function! s:toggle_build_command()
  let t:build_command_index += 1
  if t:build_command_index >= len(t:build_commands)
    let t:build_command_index = 0
  endif
endfunction

command! -nargs=* -complete=file RunBuild call <SID>reset_build_command() | call <SID>set_make_env() | execute 'RetryWithArgs ' . t:title . ' StartMake <args>' | caddexpr "Entering directory script/" | normal! <C-w>p
command! -nargs=* -complete=file RetryBuild call <SID>set_make_env() | execute 'RetryWithArgs ' . t:title | caddexpr "Entering directory script/" | normal! <C-w>p

noremap <Plug>(my-build-run) :<C-u>wa<CR>:call <SID>toggle_build_command()<CR>:RunBuild <C-r>=t:build_commands[t:build_command_index]<CR>
cnoremap <Plug>(my-build-run) :<C-u>wa<CR>:call <SID>toggle_build_command()<CR>:RunBuild <C-r>=t:build_commands[t:build_command_index]<CR>

noremap <Plug>(my-build-retry) :<C-u>wa<CR>:RetryBuild<CR>
cnoremap <Plug>(my-build-retry) :<C-u>wa<CR>:RetryBuild<CR>

nnoremap <Plug>(my-inspect) :<C-u>sil execute '!ripper-tags ' . t:project_path . '/script -f ' t:project_path . '/script/tags --tag-relative --exclude=.git --exclude=Test/ --exclude=TestScene/ -R'<CR>

let g:switch_custom_definitions =
    \ [
    \   ['horizontal_alignment', 'vertical_alignment', ],
    \   ['Alignment::TOP', 'Alignment::CENTER', 'Alignment::BOTTOM', 'Alignment::STRETCH', ],
    \   ['Orientation::HORIZONTAL', 'Orientation::VERTICAL', ],
    \   ['MOVE_UP', 'MOVE_DOWN', ],
    \   ['MOVE_LEFT', 'MOVE_RIGHT', ],
    \ ]

