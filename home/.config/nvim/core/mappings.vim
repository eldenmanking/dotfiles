let mapleader = " "

nnoremap <Leader>dq <cmd>q<CR>
nnoremap <Leader>dd <cmd>bp \| bd #<CR>
nnoremap <Leader>da <cmd>wqa<CR>
nnoremap <Leader>df <cmd>earlier 1f<CR>
nnoremap <Leader>dF <cmd>later 1f<CR>

nnoremap <Leader>ai <cmd>e $MYVIMRC<CR>
nnoremap <Leader>ap <cmd>let @+=expand('%:p:h') \| echo @+<CR>
nnoremap <Leader>aP <cmd>let @+=expand('%:p') \| echo @+<CR>
nnoremap <Leader>ae <cmd>OpenDirectory<CR>
nnoremap <Leader>aE <cmd>OpenFile<CR>
nnoremap <Leader>af <cmd>if v:count \| let &shiftwidth=v:count \| let &tabstop=v:count \| endif<CR>
nnoremap <Leader>aw <cmd>TrimTrailingWhitespace<CR>
nnoremap <Leader>as <cmd>Scratch<CR>
nnoremap <Leader>at <cmd>terminal<CR>
nnoremap <expr> <Leader>ar EditMacro() 

nnoremap <Leader>bb <cmd>buffers<CR>
nnoremap <Leader>bd <cmd>g/^/exe ":norm gf" \| exe ":norm <C-6>"<CR>
nnoremap <expr> <Leader>j BufferJump()

nnoremap <Leader>gm <cmd>Scratch<CR>:%! git diff --name-only --line-prefix=`git rev-parse --show-toplevel`/ --diff-filter=U<CR>

nnoremap <Leader>st <cmd>Scratch<CR>:%! grep -IHEnr "" . --exclude-dir={.git,} --include={\*,}<C-f>F"i
nnoremap <Leader>sf <cmd>Scratch<CR>:%! find . -not -regex ".*/\.git/.*" -type f -regex ".*/.*.*"<C-f>F.i

nnoremap <Leader>G ggVG
nnoremap <Leader>r <cmd>noh<CR>
nnoremap <Leader>w <cmd>w<CR>
nnoremap <Leader>c <cmd>CdToFile<CR>
nnoremap <Leader>C <cmd>CdToSession<CR>
nnoremap <Leader>q <cmd>qa<CR>
nnoremap <Leader>v <cmd>tab split<CR>
nnoremap <Leader>x <cmd>tabclose<CR>
nnoremap <Leader>z <C-w>\|
nnoremap <Leader>Z <C-w>=
nnoremap <Leader>Q <cmd>call TargetRegister()<CR>

" Note: Do not use <C-j> in registers; use <C-/>j instead
nnoremap <C-j> <cmd>bn<CR>
nnoremap <C-k> <cmd>bp<CR>
nnoremap <C-h> <cmd>tabp<CR>
nnoremap <C-l> <cmd>tabn<CR>
nnoremap <S-tab> <C-w>W
nnoremap <tab> <C-w>w
nnoremap <M-i> <C-i>
nnoremap <expr> j v:count ? ("m'" . v:count) . 'j' : 'gj'
nnoremap <expr> k v:count ? ("m'" . v:count) . 'k' : 'gk'
nnoremap ]n /\(<<<<<<<\\|=======\\|>>>>>>>\)<CR>
nnoremap [n ?\(<<<<<<<\\|=======\\|>>>>>>>\)<CR>

vnoremap // y/\V<C-r><C-r>=escape(@",'/\')->substitute('\n','\\n','g')<CR><CR>
nnoremap gt `[v`]

inoremap <C-d> <del>
inoremap <M-o> <CR>
nnoremap <C-f> :<C-f>"_dd
nnoremap - @:
nnoremap + @@
noremap _ g_

noremap <M-q> <cmd>ToggleSyntax<CR>
noremap <M-p> "0p
noremap <M-P> "0P

cnoremap <M-f> <C-right>
cnoremap <M-b> <C-left>
cnoremap <C-a> <C-b>
cnoremap <C-d> <del>

tnoremap <ESC> <C-\><C-n>
tnoremap <expr> <C-R> '<C-\><C-N>"' . nr2char(getchar()) . 'pi'

" universal alias for <C-j> to avoid null character issues in macros
map <C-q> <C-j>
map! <C-q> <C-j>
lmap <C-q> <C-j>
