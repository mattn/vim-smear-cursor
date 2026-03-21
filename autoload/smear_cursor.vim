vim9script

# Smear Cursor for Vim - sub-cell rendering with 1/8 block characters
# Inspired by sphamba/smear-cursor.nvim
# Uses opacity:0 popups for transparent background

var prev_pos = [0, 0]
var smear_popups: list<number> = []
var smear_tvals: list<float> = []
var anim_timer = -1

# Settings
const ERASE_INTERVAL = get(g:, 'smear_cursor_erase_interval', 10)
const MIN_DISTANCE = get(g:, 'smear_cursor_min_distance', 3)
const ASPECT = get(g:, 'smear_cursor_aspect', 2.0)
const HEAD_W = get(g:, 'smear_cursor_head_width', 0.9)
const TAIL_W = get(g:, 'smear_cursor_tail_width', 0.1)

# 1/8 block characters: height 1/8 → 8/8 (bottom-aligned)
const EIGHTH_BLOCKS = ['▁', '▂', '▃', '▄', '▅', '▆', '▇', '█']

# Color gradient: head (bright) → tail (dim)
highlight default SmearLv1 guifg=#e0e0e0 guibg=NONE ctermfg=253 ctermbg=NONE
highlight default SmearLv2 guifg=#b0b0b0 guibg=NONE ctermfg=249 ctermbg=NONE
highlight default SmearLv3 guifg=#888888 guibg=NONE ctermfg=245 ctermbg=NONE
highlight default SmearLv4 guifg=#666666 guibg=NONE ctermfg=242 ctermbg=NONE
highlight default SmearLv5 guifg=#484848 guibg=NONE ctermfg=239 ctermbg=NONE
highlight default SmearLv6 guifg=#303030 guibg=NONE ctermfg=236 ctermbg=NONE

const HLS = ['SmearLv1', 'SmearLv2', 'SmearLv3', 'SmearLv4', 'SmearLv5', 'SmearLv6']

export def StopAnim()
  if anim_timer != -1
    timer_stop(anim_timer)
    anim_timer = -1
  endif
  for p in smear_popups
    popup_close(p)
  endfor
  smear_popups = []
  smear_tvals = []
enddef

def Erase(timer_id: number)
  if len(smear_popups) == 0
    StopAnim()
    return
  endif
  # Erase ~1/3 of remaining popups per step (at least 5)
  var n = max([5, float2nr(ceil(len(smear_popups) / 3.0))])
  n = min([n, len(smear_popups)])
  for i in range(n)
    popup_close(smear_popups[i])
  endfor
  smear_popups = smear_popups[n :]
  smear_tvals = smear_tvals[n :]
  if len(smear_popups) == 0
    StopAnim()
  endif
enddef

# Sort popups by t-value (tail first) using insertion sort
def SortByT()
  var n = len(smear_tvals)
  if n < 2
    return
  endif
  for i in range(1, n - 1)
    var tv = smear_tvals[i]
    var pv = smear_popups[i]
    var j = i - 1
    while j >= 0 && smear_tvals[j] > tv
      smear_tvals[j + 1] = smear_tvals[j]
      smear_popups[j + 1] = smear_popups[j]
      j -= 1
    endwhile
    smear_tvals[j + 1] = tv
    smear_popups[j + 1] = pv
  endfor
enddef

export def OnCursorMoved()
  const spos = screenpos(0, line('.'), col('.'))
  const cur = [spos.row, spos.col]

  if prev_pos[0] == 0
    prev_pos = cur
    return
  endif

  var dr = cur[0] - prev_pos[0]
  var dc = cur[1] - prev_pos[1]
  var dist = sqrt(dr * dr * 1.0 + dc * dc)

  if dist < MIN_DISTANCE
    prev_pos = cur
    return
  endif

  StopAnim()

  # Line endpoints as float
  var r0 = prev_pos[0] * 1.0
  var c0 = prev_pos[1] * 1.0
  var r1 = cur[0] * 1.0
  var c1 = cur[1] * 1.0

  # Direction vector in aspect-corrected space
  var dra = (r1 - r0) * ASPECT
  var dca = c1 - c0
  var len_sq = dra * dra + dca * dca

  if len_sq < 0.001
    prev_pos = cur
    return
  endif

  # Bounding box with margin
  var margin = float2nr(ceil(HEAD_W)) + 1
  var rmin = min([prev_pos[0], cur[0]]) - margin
  var rmax = max([prev_pos[0], cur[0]]) + margin
  var cmin = min([prev_pos[1], cur[1]]) - margin
  var cmax = max([prev_pos[1], cur[1]]) + margin

  for row in range(rmin, rmax)
    if row < 1 || row > &lines
      continue
    endif

    for col in range(cmin, cmax)
      if col < 1 || col > &columns
        continue
      endif

      # Skip origin and destination cells
      if row == prev_pos[0] && col == prev_pos[1]
        continue
      endif
      if row == cur[0] && col == cur[1]
        continue
      endif

      # Project cell center onto line (aspect-corrected)
      const cr = row * 1.0
      const cc = col * 1.0
      const dqr = (cr - r0) * ASPECT
      const dqc = cc - c0
      const t = (dqr * dra + dqc * dca) / len_sq

      if t < -0.05 || t > 1.05
        continue
      endif

      # Clamp t for width calculation
      const ct = t < 0.0 ? 0.0 : t > 1.0 ? 1.0 : t

      # Perpendicular distance from line
      var proj_r = r0 + ct * (r1 - r0)
      var proj_c = c0 + ct * (c1 - c0)
      var pr = (cr - proj_r) * ASPECT
      var pc = cc - proj_c
      var perp = sqrt(pr * pr + pc * pc)

      # Tapered half-width: thin at tail (t=0), thick at head (t=1)
      var hw = TAIL_W + (HEAD_W - TAIL_W) * ct
      if perp >= hw
        continue
      endif

      # Map coverage to block height: factor in both distance and trail width
      var coverage = (1.0 - perp / hw) * (hw / HEAD_W)
      var blk_idx = float2nr(round(coverage * 7.0))
      if blk_idx < 0
        blk_idx = 0
      elseif blk_idx > 7
        blk_idx = 7
      endif
      var ch = EIGHTH_BLOCKS[blk_idx]

      # Color level: t=1 (head) → bright, t=0 (tail) → dim
      var lv = float2nr(round((1.0 - ct) * (len(HLS) - 1)))
      if lv < 0
        lv = 0
      elseif lv >= len(HLS)
        lv = len(HLS) - 1
      endif

      var p = popup_create(ch, {
        line: row,
        col: col,
        highlight: HLS[lv],
        opacity: 0,
        zindex: 999,
        wrap: false,
        fixed: true,
      })
      add(smear_popups, p)
      add(smear_tvals, ct)
    endfor
  endfor

  # Sort by t so tail (low t) gets erased first
  SortByT()

  if len(smear_popups) > 0
    anim_timer = timer_start(ERASE_INTERVAL, Erase, {repeat: -1})
  endif

  prev_pos = cur
enddef
