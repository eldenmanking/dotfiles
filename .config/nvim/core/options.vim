filetype plugin indent on
syntax on

set foldmethod=indent
set nofoldenable
set mouse=a
set hlsearch
set incsearch
set ignorecase

set number
set relativenumber
set wrap

set timeoutlen=250
set backspace=indent,eol,start
set complete-=i
set formatoptions=tcqjrol

set smarttab
set autoindent
set expandtab
set shiftwidth=2
set tabstop=2
set textwidth=120

set clipboard=
set undofile

if !has('nvim')
  silent execute '!mkdir -p ~/.vim/undodir'
  set undodir=~/.vim/undodir
endif

lua << EOF

vim.g.clipboard = {
  name = 'dotfilesClip',
  copy = {
    ['+'] = { 'clip' },
  },
  paste = {
    ['+'] = { 'true' },
  },
}

EOF
