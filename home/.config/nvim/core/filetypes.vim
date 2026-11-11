" Filetype specific indentation rules
augroup filetype_indentation
  au!
  autocmd FileType cs,python,java setlocal tabstop=4 shiftwidth=4
  autocmd FileType ocaml setlocal textwidth=80 colorcolumn=80
  autocmd FileType markdown setlocal textwidth=0 colorcolumn=0 shiftwidth=2
augroup end

" Spelling
augroup filetype_spelling
  au!
  autocmd FileType tex setlocal spell
augroup end
