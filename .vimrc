" Keep Vim's standard defaults even though this tracked vimrc exists.
if filereadable(expand('$VIMRUNTIME/defaults.vim'))
  source $VIMRUNTIME/defaults.vim
endif

" Keep plain y/p/d on Vim's local unnamed register. Use "+ or "* registers
" explicitly when you want the platform clipboard.
set clipboard=

set fileformats=unix,dos

if $TERM =~# '^\%(tmux\|screen\|xterm\)'
  let &t_BE = "\e[?2004h"
  let &t_BD = "\e[?2004l"
  let &t_PS = "\e[200~"
  let &t_PE = "\e[201~"
endif
