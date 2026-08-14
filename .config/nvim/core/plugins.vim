" Disable netrw
let g:loaded_netrw = 1
let g:loaded_netrwPlugin = 1

" Setup plugin manager
let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')

Plug 'catppuccin/nvim', { 'branch': 'vim', 'as': 'catppuccin' }         " Color scheme
Plug 'tpope/vim-surround'                                               " Provides some shortcuts for delimiter manipulation
Plug 'tpope/vim-commentary'	                                            " Provides commenting
Plug 'vim-airline/vim-airline' 	                                        " Provides status bars
Plug 'vim-airline/vim-airline-themes'                                   " Airline themes
Plug 'tpope/vim-obsession'                                              " Improve vim sessions functionality
Plug 'moll/vim-bbye'                                                    " More intelligent buffer deletion
Plug 'tpope/vim-fugitive'                                               " Git-integration for vim
Plug 'iamcco/markdown-preview.nvim', { 'do': 'cd app && yarn install' } " Markdown integration for neovim (requires yarn)
Plug 'folke/which-key.nvim'                                             " Keybinding hints
Plug 'akinsho/bufferline.nvim', { 'tag': '*' }                          " Buffer management
Plug 'kyazdani42/nvim-web-devicons'                                     " for coloured icons
Plug 'nvim-tree/nvim-tree.lua'                                          " file explorer

call plug#end()

" lua plugin setup
lua << EOF
-- vim.pack plugins
vim.pack.add({ 'https://github.com/dmtrKovalenko/fff' })

vim.api.nvim_create_autocmd('PackChanged', {
  callback = function(ev)
    local name, kind = ev.data.spec.name, ev.data.kind
    if name == 'fff' and (kind == 'install' or kind == 'update') then
      if not ev.data.active then vim.cmd.packadd('fff') end
      require('fff.download').download_or_build_binary()
    end
  end,
})

local function nvimTreeOnAttach(bufnr)
  local api = require "nvim-tree.api"

  -- default mappings
  api.map.on_attach.default(bufnr)

  vim.keymap.set("n", "<esc>", "<C-w>w", { buffer = bufnr })
  vim.keymap.set("n", "<Leader>e", "<cmd>NvimTreeClose<CR>", { buffer = bufnr })
end


require("which-key").setup { win = {height = 8} }
require("bufferline").setup {}
require("nvim-tree").setup { on_attach = nvimTreeOnAttach, git = { enable = false }, update_cwd = true, view = { adaptive_size = true } }

-- lua plugin configuration

vim.g.fff = {
  debug = { enabled = true, show_scores = true },
}

EOF

" vim-airline & vim-airline-themes
let g:airline#extensions#tabline#show_buffers = 0
let g:airline#extensions#tabline#enabled = 0
let g:airline#extensions#tabline#ignore_bufadd_pat = 'defx|gundo|nerd_tree|startify|tagbar|undotree|vimfiler'
let g:airline_powerline_fonts = 1

" markdown-preview.nvim
let g:mkdp_theme = 'dark'
let g:mkdp_auto_close = 0

" catppuccin setup
colorscheme catppuccin-mocha

" nvim-tree setup
let g:nvim_tree_respect_buf_cwd = 1
