vim9script

# Smear Cursor for Vim - sub-cell rendering with 2x2 matrix characters
# Inspired by sphamba/smear-cursor.nvim

if exists('g:loaded_smear_cursor')
  finish
endif
g:loaded_smear_cursor = true

augroup SmearCursor
  autocmd!
  autocmd CursorMoved * smear_cursor#OnCursorMoved()
  autocmd VimLeave * smear_cursor#StopAnim()
augroup END
