" Custom color scheme modifications
augroup colorscheme_modifications
  au!
  autocmd ColorScheme * highlight! link texCmdGreek Function
  autocmd ColorScheme * highlight! link texMathDelim Delimiter 
  autocmd ColorScheme * highlight! link texMathSymbol String " Remove '48-57' from 'iskeyword' in vimtex/syntax/core.vim
  autocmd ColorScheme * highlight! texCmdEnv gui=bold
  autocmd ColorScheme * highlight! texCmdPart gui=bold
augroup end

" Filetype specific indentation rules
augroup filetype_indentation
  au!
  autocmd FileType cs,py,java set tabstop=4 | set shiftwidth=4
  autocmd FileType ocaml set textwidth=80 | set colorcolumn=80
  autocmd FileType md set textwidth=0 | set colorcolumn=0 | set shiftwidth=2
augroup end

" Spelling
augroup filetype_spelling
  au!
  autocmd Filetype tex set spell
augroup end
