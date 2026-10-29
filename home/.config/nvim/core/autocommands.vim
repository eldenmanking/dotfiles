" Yank to system clipboard with y register
" Use WSL clipboard if applicable
if system('uname -r') =~ "Microsoft"
  augroup wsl_yank
    au!
    autocmd TextYankPost * if v:event.regname ==# 'y' | :call system('/mnt/c/windows/system32/clip.exe ',@")
  augroup END
else
  augroup system_yank
    au!
    autocmd TextyankPost * if v:event.regname ==# 'y' | let @+=@y | endif
  augroup end
endif

" Make syntax highlighting more accurate
augroup accurate_syntax_sync
  au!
  autocmd BufRead,BufNewFile * syntax sync fromstart
augroup end

" After loading a session (e.g. a tmux-resurrect restore), cd to the session file's directory
augroup session_cwd
  au!
  autocmd SessionLoadPost * silent CdToSession
augroup end
