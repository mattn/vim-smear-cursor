# vim-smear-cursor

A Vim plugin that renders a smear trail behind the cursor as it moves, using sub-cell 2x2 matrix characters (block elements) for smooth rendering. Inspired by [smear-cursor.nvim](https://github.com/sphamba/smear-cursor.nvim).

![Vim](https://img.shields.io/badge/Vim-9.0+-green)

## Requirements

- **Vim 9.0+** with `vim9script` support
- **`+popupwin`** feature
- **Popup `opacity` option support** — This plugin uses `opacity: 0` for transparent popup backgrounds. This requires a very recent Vim build (patch 9.1.1xxxor later). Check with `:echo has('patch-9.1.1xxx')` or try `:popup_create('test', #{opacity: 0})` to verify your build supports it.
- A terminal or GUI that supports Unicode block element characters (▀ ▌ █ etc.)
- A monospace font with good Unicode coverage

> **Note:** If your Vim does not support the `opacity` option for `popup_create()`, popups will render with an opaque background, which breaks the visual effect. Make sure you are running the latest Vim from source or a nightly build.

## Installation

Using [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'mattn/vim-smear-cursor'
```

Using Vim's built-in package manager:

```sh
mkdir -p ~/.vim/pack/plugins/start
cd ~/.vim/pack/plugins/start
git clone https://github.com/mattn/vim-smear-cursor.git
```

## Configuration

All settings are optional. Set them in your `vimrc` before the plugin loads:

```vim
let g:smear_cursor_erase_interval = 10   " ms per erase step (default: 10)
let g:smear_cursor_min_distance = 3      " minimum cell distance to trigger (default: 3)
let g:smear_cursor_aspect = 2.0          " terminal cell height/width ratio (default: 2.0)
let g:smear_cursor_head_width = 0.9      " half-width at head in cell units (default: 0.9)
let g:smear_cursor_tail_width = 0.1      " half-width at tail in cell units (default: 0.1)
```

### Highlight Groups

The trail color gradient can be customized by overriding the following highlight groups:

```vim
highlight SmearLv1 guifg=#e0e0e0 ctermfg=253  " head (brightest)
highlight SmearLv2 guifg=#b0b0b0 ctermfg=249
highlight SmearLv3 guifg=#888888 ctermfg=245
highlight SmearLv4 guifg=#666666 ctermfg=242
highlight SmearLv5 guifg=#484848 ctermfg=239
highlight SmearLv6 guifg=#303030 ctermfg=236  " tail (dimmest)
```

## How It Works

When the cursor moves more than `g:smear_cursor_min_distance` cells, the plugin draws a tapered trail from the previous position to the new position using Unicode 2x2 block element characters. The trail fades from bright (head) to dim (tail) and is progressively erased via a timer.

## License

MIT
