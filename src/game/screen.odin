package game

// Software renderer: the TRS-80 Color Computer's PMODE 1, colour set 0. A 128x96 screen of palette
// indices (1 green, 2 yellow, 3 blue, 4 red; 0 is transparent in sprites and never drawn), resolved
// to RGBA for the page. Text is the Anvil's default font, 4x6 cells (font.odin).

SCREEN_W :: 128
SCREEN_H :: 96
CELL :: 8
PANEL_X :: ROOM * CELL // the 32-pixel text panel: 8 characters by 16 lines
PANEL_COLS :: 8
PAGE_COLS :: 32
PAGE_ROWS :: 16

GREEN :: 1
YELLOW :: 2
BLUE :: 3
RED :: 4

PALETTE := [5]u32{0x00FF00, 0x00FF00, 0xFFFF00, 0x0000FF, 0xFF0000}

Frame :: struct {
	px:   [SCREEN_W * SCREEN_H]u8,
	rgba: [SCREEN_W * SCREEN_H]u32, // 0xAABBGGRR (little-endian R,G,B,A bytes)
}

cls :: proc(f: ^Frame, c: u8) {
	for &p in f.px {
		p = c
	}
}

set_px :: proc(f: ^Frame, x, y: int, c: u8) {
	if x < 0 || y < 0 || x >= SCREEN_W || y >= SCREEN_H {
		return
	}
	f.px[y * SCREEN_W + x] = c
}

fill_rect :: proc(f: ^Frame, x, y, w, h: int, c: u8) {
	for yy in y ..< y + h {
		for xx in x ..< x + w {
			set_px(f, xx, yy, c)
		}
	}
}

// Draws an 8x8 picture; colour 0 is transparent.
draw_gfx :: proc(f: ^Frame, g: Gfx, x, y: int) {
	pic := &GFX[g]
	for i in 0 ..< CELL * CELL {
		c := pic[i]
		if c != 0 {
			set_px(f, x + i % CELL, y + i / CELL, c)
		}
	}
}

// Prints in 4x6 cells; characters outside ASCII 32..126 show as '?'. Returns the width drawn.
print :: proc(f: ^Frame, text: string, x, y: int, color: u8) -> int {
	for i in 0 ..< len(text) {
		ch := text[i]
		if ch < 32 || ch > 126 {
			ch = '?'
		}
		rows := &FONT[ch - 32]
		for row in 0 ..< GLYPH_H {
			bits := rows[row]
			for col in 0 ..< GLYPH_W {
				if bits & (0x80 >> uint(col)) != 0 {
					set_px(f, x + i * GLYPH_W + col, y + row, color)
				}
			}
		}
	}
	return len(text) * GLYPH_W
}

// Writes palette indices through the palette into rgba.
resolve :: proc(f: ^Frame) {
	for p, i in f.px {
		c := PALETTE[p if p < 5 else 0]
		f.rgba[i] = 0xFF000000 | (c & 0xFF) << 16 | (c >> 8 & 0xFF) << 8 | (c >> 16 & 0xFF)
	}
}

// A short text built without allocation (the game package uses no core:fmt).
Text :: struct {
	buf: [PAGE_COLS]u8,
	n:   int,
}

t_str :: proc(t: ^Text, s: string) {
	for i in 0 ..< len(s) {
		if t.n < len(t.buf) {
			t.buf[t.n] = s[i]
			t.n += 1
		}
	}
}

// Appends v in decimal, padded with zeros to `width` digits.
t_int :: proc(t: ^Text, v: int, width := 0) {
	tmp: [12]u8
	n := 0
	x := v if v >= 0 else -v
	for {
		tmp[n] = u8('0' + x % 10)
		n += 1
		x /= 10
		if x == 0 {
			break
		}
	}
	for n < width && n < len(tmp) {
		tmp[n] = '0'
		n += 1
	}
	if v < 0 {
		t_str(t, "-")
	}
	for i := n - 1; i >= 0; i -= 1 {
		if t.n < len(t.buf) {
			t.buf[t.n] = tmp[i]
			t.n += 1
		}
	}
}

t_string :: proc(t: ^Text) -> string {
	return string(t.buf[:t.n])
}
