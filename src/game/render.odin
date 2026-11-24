package game

// Lays out the screen: the 12x12 room on the left, the 8-column panel on the right, or a full-screen
// page of lore (32 by 16).

draw_game :: proc(f: ^Frame, g: ^Game) {
	switch g.phase {
	case .Title, .Lore, .Sign, .Won:
		draw_page(f, g.page)
	case .Game_Over:
		draw_game_over(f, g)
	case .Play, .Dead, .Confirm:
		draw_room(f, g)
		draw_panel(f, g)
	}
}

draw_page :: proc(f: ^Frame, lines: []string) {
	cls(f, BLUE)
	for line, i in lines {
		if i >= PAGE_ROWS - 1 {
			break
		}
		print(f, line, 0, i * GLYPH_H, YELLOW if i == 0 else GREEN)
	}
	prompt :: "SPACE TO GO ON"
	print(f, prompt, SCREEN_W - len(prompt) * GLYPH_W, (PAGE_ROWS - 1) * GLYPH_H, YELLOW)
}

draw_game_over :: proc(f: ^Frame, g: ^Game) {
	cls(f, BLUE)
	for line, i in GAME_OVER_LINES {
		print(f, line, 0, i * GLYPH_H, RED if i == 0 else GREEN)
	}
	row := len(GAME_OVER_LINES) + 1
	n := 0
	for r, b in g.cp_reached {
		if !r {
			continue
		}
		t: Text
		t_str(&t, "> " if n == g.choice else "  ")
		t_str(&t, "CHECKPOINT: LEVEL ")
		t_int(&t, b * BLOCK_LEVELS + 1)
		print(f, t_string(&t), 0, (row + n) * GLYPH_H, YELLOW if n == g.choice else GREEN)
		n += 1
	}
}

terrain_gfx :: proc(g: ^Game, x, y: int) -> Gfx {
	switch g.terrain[y][x] {
	case .Floor:
		return .Floor
	case .Wall:
		return .Wall
	case .Slot:
		return .Wall_Slot
	case .Nozzle:
		return .Wall_Nozzle
	case .Seam:
		return .Wall_Seam
	case .Cracked_Wall:
		return .Wall_Cracked
	case .Fake_Wall:
		return .Wall_Fake
	case .Alcove:
		return .Alcove
	case .Hidden_Pit:
		return .Floor_Cracked
	case .Crumble:
		return .Floor_Crumble
	case .Spikes:
		return .Spikes_Up if spikes_up(g.turn) else .Spikes_Down
	case .Plate:
		return .Plate_Down if plate_pressed(g, x, y) else .Plate
	case .Pit:
		return .Pit
	case .Filled_Pit:
		return .Pit_Filled
	case .Rubble:
		return .Rubble
	case .Stairs:
		return .Stairs
	case .Door_Yellow:
		return .Door_Yellow
	case .Door_Red:
		return .Door_Red
	case .Door_Blue:
		return .Door_Blue
	case .Gate:
		return .Floor if gate_open(g) else .Gate
	case .One_Way_N:
		return .Arrow_Up
	case .One_Way_S:
		return .Arrow_Down
	case .One_Way_W:
		return .Arrow_Left
	case .One_Way_E:
		return .Arrow_Right
	}
	return .Floor
}

ITEM_GFX := [Item_Kind]Gfx {
	.None       = .Floor,
	.Coin       = .Coin,
	.Key_Yellow = .Key_Yellow,
	.Key_Red    = .Key_Red,
	.Key_Blue   = .Key_Blue,
	.Gem        = .Gem,
	.Potion     = .Potion,
	.Oneup      = .Oneup,
	.Sword      = .Sword1,
	.Shield     = .Shield1,
	.Pick       = .Pick,
	.Lamp       = .Lamp,
	.Bomb       = .Bomb,
	.Sign       = .Sign,
}

MONSTER_GFX := [Monster_Kind]Gfx {
	.Slime = .Slime,
	.Ghost = .Ghost,
	.Eye   = .Eye,
}

// Unlit cells in a dark level without the lamp: everything beyond the player's neighbours.
lit :: proc(g: ^Game, x, y: int) -> bool {
	if !LEVELS[g.level].dark || g.p.lamp {
		return true
	}
	return abs(x - g.x) <= 1 && abs(y - g.y) <= 1
}

// Can the player see what is in this cell?
shown :: proc(g: ^Game, x, y: int) -> bool {
	return lit(g, x, y) && !g.secret[y][x]
}

draw_room :: proc(f: ^Frame, g: ^Game) {
	for y in 0 ..< ROOM {
		for x in 0 ..< ROOM {
			if !lit(g, x, y) {
				fill_rect(f, x * CELL, y * CELL, CELL, CELL, BLUE)
				continue
			}
			if g.secret[y][x] {
				draw_gfx(f, .Wall, x * CELL, y * CELL)
				continue
			}
			draw_gfx(f, terrain_gfx(g, x, y), x * CELL, y * CELL)
			if g.block[y][x] {
				draw_gfx(f, .Block, x * CELL, y * CELL)
			}
			if burning(g, x, y) {
				draw_gfx(f, .Flame, x * CELL, y * CELL)
			}
		}
	}
	for i in 0 ..< g.item_count {
		it := &g.items[i]
		if !it.taken && shown(g, it.x, it.y) {
			draw_gfx(f, ITEM_GFX[it.kind], it.x * CELL, it.y * CELL)
		}
	}
	for i in 0 ..< g.monster_count {
		m := &g.monsters[i]
		if !m.dead && shown(g, m.x, m.y) {
			draw_gfx(f, MONSTER_GFX[m.kind], m.x * CELL, m.y * CELL)
		}
	}
	for a in g.arrows {
		if a.live && in_room(a.x, a.y) && shown(g, a.x, a.y) {
			draw_gfx(f, .Arrow_H if a.dy == 0 else .Arrow_V, a.x * CELL, a.y * CELL)
		}
	}
	if g.phase != .Dead || g.death != "FELL" {
		draw_gfx(f, .Hero, g.x * CELL, g.y * CELL)
	}
}

panel_line :: proc(f: ^Frame, row: int, text: string, color: u8 = YELLOW) {
	print(f, text, PANEL_X, row * GLYPH_H, color)
}

draw_panel :: proc(f: ^Frame, g: ^Game) {
	fill_rect(f, PANEL_X, 0, SCREEN_W - PANEL_X, SCREEN_H, BLUE)
	p := &g.p
	{
		t: Text
		t_str(&t, "L")
		t_int(&t, g.level + 1, 2)
		t_str(&t, " T")
		t_int(&t, g.turn % 1000)
		panel_line(f, 0, t_string(&t))
	}
	{
		t: Text
		t_str(&t, "HP ")
		t_int(&t, p.hp)
		t_str(&t, "/")
		t_int(&t, MAX_HP)
		panel_line(f, 1, t_string(&t), RED if p.hp <= 3 else YELLOW)
	}
	{
		t: Text
		t_str(&t, "$")
		t_int(&t, min(p.money, 9999), 4)
		panel_line(f, 2, t_string(&t))
	}
	{
		t: Text
		t_str(&t, "LIVES ")
		t_int(&t, g.lives)
		panel_line(f, 3, t_string(&t))
	}
	{
		t: Text
		t_str(&t, "R")
		t_int(&t, min(p.keys[1], 9))
		t_str(&t, " Y")
		t_int(&t, min(p.keys[0], 9))
		t_str(&t, " B")
		t_int(&t, min(p.keys[2], 9))
		panel_line(f, 4, t_string(&t))
	}
	{
		t: Text
		t_str(&t, "AT")
		t_int(&t, 1 + p.sword)
		t_str(&t, " DF")
		t_int(&t, p.shield)
		panel_line(f, 5, t_string(&t))
	}
	{
		t: Text
		t_str(&t, "BOMBS ")
		t_int(&t, min(p.bombs, 9))
		panel_line(f, 6, t_string(&t))
	}
	{
		t: Text
		t_str(&t, "PCK " if p.pick else "--- ")
		t_str(&t, "LAMP" if p.lamp else "----")
		panel_line(f, 7, t_string(&t))
	}
	{
		found, total := gems_in_block(g)
		t: Text
		t_str(&t, "GEM ")
		t_int(&t, found)
		t_str(&t, "/")
		t_int(&t, total)
		panel_line(f, 8, t_string(&t))
	}
	panel_line(f, 9, LEVELS[g.level].name, GREEN)
	fill_rect(f, PANEL_X, 10 * GLYPH_H + 2, SCREEN_W - PANEL_X, 1, GREEN)
	for i in 0 ..< LOG_LINES - 1 {
		m := &g.log[i]
		if m.n > 0 {
			panel_line(f, 15 - i, string(m.buf[:m.n]), m.color)
		}
	}
}
