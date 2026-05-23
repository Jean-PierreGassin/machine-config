" Keep Vim's standard defaults even though this tracked vimrc exists.
if filereadable(expand('$VIMRUNTIME/defaults.vim'))
  source $VIMRUNTIME/defaults.vim
endif

" Keep plain y/p/d on Vim's local unnamed register. Use "+ or "* registers
" explicitly when you want the platform clipboard.
set clipboard=
set fileformats=unix,dos

" Enable filetype-specific features (still good to keep active)
filetype plugin indent on

" Global indentation settings for all files
set tabstop=2       " Number of spaces a tab counts for
set shiftwidth=2    " Number of spaces for auto-indenting
set expandtab       " Turn tabs into spaces
set autoindent      " Copy indent from current line when starting a new line

if $TERM =~# '^\%(tmux\|screen\|xterm\)'
  let &t_BE = "\e[?2004h"
  let &t_BD = "\e[?2004l"
  let &t_PS = "\e[200~"
  let &t_PE = "\e[201~"
endif
