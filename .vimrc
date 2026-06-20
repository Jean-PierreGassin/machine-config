" ============================================================
" Defaults
" ============================================================
" Keep Vim's standard defaults even though this tracked vimrc exists.
if filereadable(expand('$VIMRUNTIME/defaults.vim'))
  source $VIMRUNTIME/defaults.vim
endif

" ============================================================
" Clipboard & file format
" ============================================================
" Keep plain y/p/d on Vim's local unnamed register. Use "+ or "*
" registers explicitly when you want the platform clipboard.
if has('clipboard')
  if has('unnamedplus')
    set clipboard=unnamedplus
  else
    set clipboard=unnamed
  endif
endif
set fileformats=unix,dos

" ============================================================
" Syntax & filetype
" ============================================================
syntax on
filetype plugin indent on

" ============================================================
" Indentation (global default)
"
" NOTE: this is 2-space for everything, which suits JS/TS/Vue/YAML
" but not PHP (PSR-12 wants 4-space). Vim doesn't read .editorconfig
" natively — either add a `:autocmd FileType php setlocal ts=4 sw=4`
" override here, or install the editorconfig-vim plugin so it picks
" up each project's .editorconfig automatically.
" ============================================================
set tabstop=2       " Number of spaces a tab counts for
set shiftwidth=2    " Number of spaces for auto-indenting
set expandtab       " Turn tabs into spaces
set autoindent      " Copy indent from current line when starting a new line

" ============================================================
" Terminal / bracketed paste support
" ============================================================
if $TERM =~# '^\%(tmux\|screen\|xterm\)'
  let &t_BE = "\e[?2004h"
  let &t_BD = "\e[?2004l"
  let &t_PS = "\e[200~"
  let &t_PE = "\e[201~"
endif
