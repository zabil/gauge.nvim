" ftplugin/gauge.vim
if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal commentstring=#\ %s
setlocal tabstop=2 shiftwidth=2 expandtab

let b:undo_ftplugin = 'setl commentstring< tabstop< shiftwidth< expandtab<'
