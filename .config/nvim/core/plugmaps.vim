" moll/vim-bbye: intelligent buffer deletion (overrides <Leader>dd)
nnoremap <Leader>dd <cmd>Bdelete<CR>

" tpope/vim-obsession: shortcut for editing Sessionx.vim file
nnoremap <Leader>ax <cmd>if v:this_session != "" \| execute "e " . substitute(g:this_obsession, "Session.vim", "Sessionx.vim", "") \| endif<CR>

" lervag/vimtex: Prevent vimtex from stealing ts chord
nnoremap ts<Space> ts

" lervag/vimtex: Jump to clipboard line number
nnoremap \t <cmd>JumpToClipboard<CR>

" tpope/vim-commentary: Mappings for toggling comments
nmap <Leader>/ gcc
vmap <Leader>/ gc

" tpope/vim-fugitive: git shortcuts
nnoremap go <cmd>Git<CR><C-w>o
nnoremap <Leader>gt <cmd>Gvdiffsplit!<CR>

" iamcco/markdown-preview.nvim: preview shortcuts
nnoremap <Leader>am <cmd>MarkdownPreview<CR>
nnoremap <Leader>aM <cmd>MarkdownPreviewStop<CR>

" akinsho/bufferline.nvim: buffer close shortcuts
nnoremap <Leader>bl <cmd>BufferLineCloseLeft<CR>
nnoremap <Leader>br <cmd>BufferLineCloseRight<CR>
nnoremap <Leader>bo <cmd>BufferLineCloseOthers<CR><C-w>o

" nvim-tree/nvim-tree.lua
nnoremap <Leader>e <cmd>NvimTreeOpen<CR>


" lua plugin keymappings
lua << EOF

-- dmtrKovalenko/fff: fast search
vim.keymap.set('n', '<Leader>f', function() require('fff').find_files() end, { desc = 'FFFind files' })
vim.keymap.set('n', '<Leader>t', function() require('fff').live_grep() end, { desc = 'FFFind content' })

EOF
