package game

// The rules: pure and deterministic (no dice, no clock). The design and the user's decisions are in
// the vault note Games/Lore Dumpster of SPLORR!!.md.
//
// A turn: the player acts (a bump into a wall costs nothing), then the monsters, then the turn counter
// ticks and the traps run on it: spikes are up when turn % 3 == 2, arrow slots fire when
// turn % 4 == 0 (an arrow flies a cell a turn), fire jets burn when turn % 4 >= 2.

ROOM :: 12
MAX_ITEMS :: 32 // placed things per level; a monster's drop has id MAX_ITEMS + its monster id
MAX_MONSTERS :: 16
MAX_ARROWS :: 16
MAX_LEVELS :: 30
BLOCK_LEVELS :: 10 // a checkpoint at the start of every block
MAX_BLOCKS :: MAX_LEVELS / BLOCK_LEVELS
START_LIVES :: 5
MAX_LIVES :: 9
MAX_HP :: 10
POTION_HEAL :: 5
COIN_VALUE :: 5
MAX_TIER :: 3
LOG_LINES :: 6
SPIKE_PERIOD :: 3
ARROW_PERIOD :: 4
FIRE_PERIOD :: 4

Command :: enum u8 {
	North,
	South,
	West,
	East,
	Wait, // also OK on pages
	Bomb,
	Restart,
	Ok,
	Cancel,
}

Terrain :: enum u8 {
	Floor,
	Wall,
	Slot,
	Nozzle,
	Seam,
	Cracked_Wall,
	Fake_Wall,
	Alcove,
	Hidden_Pit,
	Crumble,
	Spikes,
	Plate,
	Pit,
	Filled_Pit,
	Rubble,
	Stairs,
	Door_Yellow,
	Door_Red,
	Door_Blue,
	Gate,
	One_Way_N,
	One_Way_S,
	One_Way_W,
	One_Way_E,
}

Item_Kind :: enum u8 {
	None,
	Coin,
	Key_Yellow,
	Key_Red,
	Key_Blue,
	Gem,
	Potion,
	Oneup,
	Sword,
	Shield,
	Pick,
	Lamp,
	Bomb,
	Sign,
}

Monster_Kind :: enum u8 {
	Slime,
	Ghost,
	Eye,
}

MONSTER_HP := [Monster_Kind]int {
	.Slime = 2,
	.Ghost = 3,
	.Eye   = 4,
}

MONSTER_ATTACK := [Monster_Kind]int {
	.Slime = 1,
	.Ghost = 2,
	.Eye   = 2,
}

Item :: struct {
	kind:  Item_Kind,
	x, y:  int,
	id:    int,
	page:  int, // signs: which page of the level's `signs`
	taken: bool,
}

Monster :: struct {
	kind:   Monster_Kind,
	x, y:   int,
	dx, dy: int,
	hp:     int,
	id:     int,
	carry:  Item_Kind,
	dead:   bool,
}

Arrow :: struct {
	x, y, dx, dy: int,
	live:         bool,
}

Ids :: bit_set[0 ..< 64;u64]

// What has happened in one level: taken things (by id), slain monsters, opened doors. The run's copy
// becomes permanent (`banked`) when the next checkpoint is reached.
Record :: struct {
	taken:  Ids,
	slain:  Ids,
	opened: Ids,
}

Player :: struct {
	hp:            int,
	money:         int,
	keys:          [3]int, // yellow, red, blue
	sword, shield: int, // tiers 0..3
	bombs:         int,
	pick, lamp:    bool,
	oneups_bought: int,
}

Phase :: enum u8 {
	Title,
	Lore, // the level's intro page
	Play,
	Sign,
	Dead,
	Confirm, // restart? (costs a life)
	Game_Over,
	Won,
}

Msg :: struct {
	buf:   [PANEL_COLS]u8,
	n:     int,
	color: u8,
}

Game :: struct {
	phase:         Phase,
	level:         int,
	p:             Player,
	lives:         int,
	x, y:          int,
	turn:          int,
	terrain:       [ROOM][ROOM]Terrain,
	block:         [ROOM][ROOM]bool,
	door_id:       [ROOM][ROOM]int,
	secret:        [ROOM][ROOM]bool, // cells reached only through a fake wall, drawn as wall until found
	items:         [MAX_ITEMS + MAX_MONSTERS]Item,
	item_count:    int,
	monsters:      [MAX_MONSTERS]Monster,
	monster_count: int,
	arrows:        [MAX_ARROWS]Arrow,
	run, banked:   [MAX_LEVELS]Record,
	entry_player:  Player, // the player on entering this level: a restart puts it back (not the lives)
	entry_record:  Record,
	cp_player:     [MAX_BLOCKS]Player, // the player on first reaching each checkpoint
	cp_reached:    [MAX_BLOCKS]bool,
	choice:        int, // Game_Over: the checkpoint picked
	page:          []string,
	death:         string,
	log:           [LOG_LINES]Msg,
	sounds:        [16]Sound,
	sound_count:   i32,
}

init_game :: proc(g: ^Game) {
	g^ = {}
	g.phase = .Title
	g.page = TITLE_PAGE
}

new_game :: proc(g: ^Game) {
	g^ = {}
	g.p = Player {
		hp = MAX_HP,
	}
	g.lives = START_LIVES
	enter_level(g, 0)
}

play :: proc(g: ^Game, s: Sound) {
	if int(g.sound_count) < len(g.sounds) {
		g.sounds[g.sound_count] = s
		g.sound_count += 1
	}
}

say :: proc(g: ^Game, text: string, color: u8 = GREEN) {
	for i := LOG_LINES - 1; i > 0; i -= 1 {
		g.log[i] = g.log[i - 1]
	}
	m := Msg {
		color = color,
	}
	for i in 0 ..< min(len(text), PANEL_COLS) {
		m.buf[i] = text[i]
	}
	m.n = min(len(text), PANEL_COLS)
	g.log[0] = m
}

say_num :: proc(g: ^Game, prefix: string, v: int, color: u8 = GREEN) {
	t: Text
	t_str(&t, prefix)
	t_int(&t, v)
	say(g, t_string(&t), color)
}

// --- levels ------------------------------------------------------------------------------------

enter_level :: proc(g: ^Game, i: int) {
	g.level = i
	if i % BLOCK_LEVELS == 0 {
		b := i / BLOCK_LEVELS
		g.banked = g.run // pickups, kills and doors so far are now for good
		if !g.cp_reached[b] {
			g.cp_reached[b] = true
			g.cp_player[b] = g.p
		}
		if i > 0 {
			play(g, .Checkpoint)
		}
	}
	g.entry_player = g.p
	g.entry_record = g.run[i]
	build_level(g)
	g.phase = .Lore
	g.page = LEVELS[i].intro
}

build_level :: proc(g: ^Game) {
	lv := &LEVELS[g.level]
	rec := g.run[g.level]
	g.terrain = {}
	g.block = {}
	g.door_id = {}
	g.secret = {}
	g.items = {}
	g.monsters = {}
	g.arrows = {}
	g.item_count = 0
	g.monster_count = 0
	g.turn = 0
	g.log = {}
	doors, signs, placed := 0, 0, 0
	for y in 0 ..< ROOM {
		row := lv.rows[y]
		for x in 0 ..< ROOM {
			ch := row[x]
			t := Terrain.Floor
			item := Item_Kind.None
			switch ch {
			case '#':
				t = .Wall
			case 's':
				t = .Slot
			case 'n':
				t = .Nozzle
			case 'm':
				t = .Seam
			case 'c':
				t = .Cracked_Wall
			case 'f':
				t = .Fake_Wall
			case 'a':
				t = .Alcove
			case 'h':
				t = .Hidden_Pit
			case 'u':
				t = .Crumble
			case '^':
				t = .Spikes
			case 'p':
				t = .Plate
			case 'O':
				t = .Pit
			case '%':
				t = .Rubble
			case 'X':
				t = .Stairs
			case 'Y':
				t = .Door_Yellow
			case 'R':
				t = .Door_Red
			case 'B':
				t = .Door_Blue
			case 'G':
				t = .Gate
			case 'A':
				t = .One_Way_N
			case 'V':
				t = .One_Way_S
			case '<':
				t = .One_Way_W
			case '>':
				t = .One_Way_E
			case '=':
				g.block[y][x] = true
			case '@':
				g.x, g.y = x, y
			case '$':
				item = .Coin
			case '*':
				item = .Gem
			case '+':
				item = .Potion
			case '1':
				item = .Oneup
			case '/':
				item = .Sword
			case ')':
				item = .Shield
			case 't':
				item = .Pick
			case 'L':
				item = .Lamp
			case 'o':
				item = .Bomb
			case '?':
				item = .Sign
			case 'y':
				item = .Key_Yellow
			case 'r':
				item = .Key_Red
			case 'b':
				item = .Key_Blue
			case 'S', 'Z', 'g', 'E':
				id := g.monster_count
				m := Monster {
					x  = x,
					y  = y,
					id = id,
				}
				switch ch {
				case 'S':
					m.kind = .Slime
					m.dx = 1
				case 'Z':
					m.kind = .Slime
					m.dy = 1
				case 'g':
					m.kind = .Ghost
				case 'E':
					m.kind = .Eye
				}
				m.hp = MONSTER_HP[m.kind]
				if id < len(lv.carries) {
					m.carry = lv.carries[id]
				}
				m.dead = id in rec.slain
				g.monsters[id] = m
				g.monster_count += 1
				if m.dead && m.carry != .None && (MAX_ITEMS + id) not_in rec.taken {
					add_item(g, m.carry, x, y, MAX_ITEMS + id)
				}
			}
			if t >= .Door_Yellow && t <= .Door_Blue {
				g.door_id[y][x] = doors
				if doors in rec.opened {
					t = .Floor
				}
				doors += 1
			}
			g.terrain[y][x] = t
			if item != .None {
				id := placed
				placed += 1
				it := add_item(g, item, x, y, id)
				if item == .Sign {
					it.page = signs
					signs += 1
				}
				it.taken = id in rec.taken
			}
		}
	}
	find_secrets(g)
}

// Everything the player cannot reach from the start without walking through a fake wall is secret.
find_secrets :: proc(g: ^Game) {
	seen: [ROOM][ROOM]bool
	stack: [ROOM * ROOM][2]int
	n := 0
	stack[0] = {g.x, g.y}
	n = 1
	seen[g.y][g.x] = true
	DIRS := [4][2]int{{0, -1}, {0, 1}, {-1, 0}, {1, 0}}
	for n > 0 {
		n -= 1
		c := stack[n]
		for d in DIRS {
			x, y := c.x + d.x, c.y + d.y
			if !in_room(x, y) || seen[y][x] || blocks_search(g.terrain[y][x]) {
				continue
			}
			seen[y][x] = true
			stack[n] = {x, y}
			n += 1
		}
	}
	for y in 0 ..< ROOM {
		for x in 0 ..< ROOM {
			g.secret[y][x] = !seen[y][x] && !blocks_search(g.terrain[y][x])
		}
	}
}

blocks_search :: proc(t: Terrain) -> bool {
	#partial switch t {
	case .Wall, .Slot, .Nozzle, .Seam, .Alcove, .Fake_Wall:
		return true
	}
	return false
}

// Walking through a fake wall uncovers the secret cells joined to it.
reveal_secret :: proc(g: ^Game, sx, sy: int) {
	stack: [ROOM * ROOM][2]int
	stack[0] = {sx, sy}
	n := 1
	DIRS := [4][2]int{{0, -1}, {0, 1}, {-1, 0}, {1, 0}}
	for n > 0 {
		n -= 1
		c := stack[n]
		for d in DIRS {
			x, y := c.x + d.x, c.y + d.y
			if in_room(x, y) && g.secret[y][x] {
				g.secret[y][x] = false
				stack[n] = {x, y}
				n += 1
			}
		}
	}
}

add_item :: proc(g: ^Game, kind: Item_Kind, x, y, id: int) -> ^Item {
	it := &g.items[g.item_count]
	it^ = Item {
		kind = kind,
		x    = x,
		y    = y,
		id   = id,
	}
	g.item_count += 1
	return it
}

// --- queries -----------------------------------------------------------------------------------

in_room :: proc(x, y: int) -> bool {
	return x >= 0 && y >= 0 && x < ROOM && y < ROOM
}

monster_at :: proc(g: ^Game, x, y: int) -> int {
	for i in 0 ..< g.monster_count {
		m := &g.monsters[i]
		if !m.dead && m.x == x && m.y == y {
			return i
		}
	}
	return -1
}

item_at :: proc(g: ^Game, x, y: int, kind := Item_Kind.None) -> int {
	for i in 0 ..< g.item_count {
		it := &g.items[i]
		if !it.taken && it.x == x && it.y == y && (kind == .None || it.kind == kind) {
			return i
		}
	}
	return -1
}

// A gate is open while anything weighs down a plate: the player, a block or a monster.
gate_open :: proc(g: ^Game) -> bool {
	for y in 0 ..< ROOM {
		for x in 0 ..< ROOM {
			if g.terrain[y][x] == .Plate && plate_pressed(g, x, y) {
				return true
			}
		}
	}
	return false
}

plate_pressed :: proc(g: ^Game, x, y: int) -> bool {
	return (g.x == x && g.y == y) || g.block[y][x] || monster_at(g, x, y) >= 0
}

spikes_up :: proc(turn: int) -> bool {
	return turn % SPIKE_PERIOD == SPIKE_PERIOD - 1
}

fire_on :: proc(turn: int) -> bool {
	return turn % FIRE_PERIOD >= FIRE_PERIOD / 2
}

// Terrain that stops arrows, flames and everything else.
solid :: proc(g: ^Game, x, y: int) -> bool {
	if !in_room(x, y) {
		return true
	}
	#partial switch g.terrain[y][x] {
	case .Wall, .Slot, .Nozzle, .Seam, .Cracked_Wall, .Fake_Wall, .Alcove, .Rubble, .Door_Yellow, .Door_Red, .Door_Blue:
		return true
	case .Gate:
		return !gate_open(g)
	}
	return g.block[y][x] || item_at(g, x, y, .Sign) >= 0
}

// The first open neighbour of a slot or nozzle: the way it faces.
facing :: proc(g: ^Game, x, y: int) -> (dx, dy: int) {
	DIRS := [4][2]int{{0, -1}, {0, 1}, {-1, 0}, {1, 0}}
	for d in DIRS {
		if !solid(g, x + d.x, y + d.y) {
			return d.x, d.y
		}
	}
	return 0, 0
}

// Is (x, y) in a fire jet's flame this turn?
burning :: proc(g: ^Game, x, y: int) -> bool {
	if !fire_on(g.turn) {
		return false
	}
	for ny in 0 ..< ROOM {
		for nx in 0 ..< ROOM {
			if g.terrain[ny][nx] != .Nozzle {
				continue
			}
			dx, dy := facing(g, nx, ny)
			if dx == 0 && dy == 0 {
				continue
			}
			cx, cy := nx + dx, ny + dy
			for !solid(g, cx, cy) {
				if cx == x && cy == y {
					return true
				}
				cx += dx
				cy += dy
			}
		}
	}
	return false
}

// Cells a monster may step into. Slimes keep away from pits; ghosts do not (and fall).
monster_can_enter :: proc(g: ^Game, m: ^Monster, x, y: int) -> bool {
	if solid(g, x, y) || monster_at(g, x, y) >= 0 || (g.x == x && g.y == y) {
		return false
	}
	#partial switch g.terrain[y][x] {
	case .Pit, .Hidden_Pit:
		return m.kind == .Ghost
	case .Stairs, .One_Way_N, .One_Way_S, .One_Way_W, .One_Way_E:
		return false
	}
	return true
}

// --- input ---------------------------------------------------------------------------------------

command :: proc(g: ^Game, c: Command) {
	switch g.phase {
	case .Title:
		if c == .Ok || c == .Wait {
			new_game(g)
			play(g, .Page)
		}
	case .Lore, .Sign:
		if c == .Ok || c == .Wait || c == .Cancel {
			g.phase = .Play
			play(g, .Page)
		}
	case .Won:
		if c == .Ok || c == .Wait {
			init_game(g)
		}
	case .Dead:
		if c == .Ok || c == .Wait {
			lose_life(g)
		}
	case .Confirm:
		if c == .Ok || c == .Wait {
			play(g, .Dead)
			lose_life(g)
		} else if c == .Cancel {
			g.phase = .Play
			say(g, "CARRY ON")
		}
	case .Game_Over:
		game_over_command(g, c)
	case .Play:
		switch c {
		case .North:
			step(g, 0, -1)
		case .South:
			step(g, 0, 1)
		case .West:
			step(g, -1, 0)
		case .East:
			step(g, 1, 0)
		case .Wait, .Ok:
			end_turn(g)
		case .Bomb:
			throw_bomb(g)
		case .Restart:
			g.phase = .Confirm
			say(g, "SURE?", RED)
			say(g, "SPC=Y N", RED)
		case .Cancel:
		}
	}
}

game_over_command :: proc(g: ^Game, c: Command) {
	count := 0
	for r in g.cp_reached {
		if r {
			count += 1
		}
	}
	#partial switch c {
	case .North, .West:
		g.choice = max(g.choice - 1, 0)
	case .South, .East:
		g.choice = min(g.choice + 1, count - 1)
	case .Ok, .Wait:
		start_from_checkpoint(g, g.choice)
	}
}

start_from_checkpoint :: proc(g: ^Game, b: int) {
	if b < 0 || b >= MAX_BLOCKS || !g.cp_reached[b] {
		return
	}
	g.p = g.cp_player[b]
	g.lives = START_LIVES
	g.run = g.banked // pickups since the last checkpoint go back into their levels
	enter_level(g, b * BLOCK_LEVELS)
}

die :: proc(g: ^Game, why: string) {
	g.phase = .Dead
	g.death = why
	say(g, why, RED)
	say(g, "SPACE", YELLOW)
	play(g, .Dead)
}

// A death or a restart: one life, then the level again with the player as they came in.
lose_life :: proc(g: ^Game) {
	g.lives -= 1
	if g.lives <= 0 {
		g.lives = 0
		g.phase = .Game_Over
		g.choice = 0
		for r, i in g.cp_reached {
			if r {
				g.choice = i
			}
		}
		play(g, .Gameover)
		return
	}
	g.p = g.entry_player
	g.run[g.level] = g.entry_record
	build_level(g)
	g.phase = .Play
	say(g, "AGAIN")
}

// --- the player's turn -----------------------------------------------------------------------------

step :: proc(g: ^Game, dx, dy: int) {
	nx, ny := g.x + dx, g.y + dy
	if !in_room(nx, ny) {
		play(g, .Bump)
		return
	}
	if mi := monster_at(g, nx, ny); mi >= 0 {
		attack(g, &g.monsters[mi])
		end_turn(g)
		return
	}
	if si := item_at(g, nx, ny, .Sign); si >= 0 {
		lv := &LEVELS[g.level]
		page := g.items[si].page
		if page < len(lv.signs) {
			g.page = lv.signs[page]
			g.phase = .Sign
			play(g, .Page)
		}
		return
	}
	t := g.terrain[ny][nx]
	#partial switch t {
	case .Wall, .Slot, .Nozzle, .Seam, .Cracked_Wall, .Alcove:
		play(g, .Bump)
		return
	case .Door_Yellow, .Door_Red, .Door_Blue:
		k := int(t) - int(Terrain.Door_Yellow)
		if g.p.keys[k] > 0 {
			g.p.keys[k] -= 1
			g.terrain[ny][nx] = .Floor
			g.run[g.level].opened += {g.door_id[ny][nx]}
			say(g, "OPENED")
			play(g, .Door)
			end_turn(g)
		} else {
			say(g, "LOCKED")
			play(g, .Nope)
		}
		return
	case .Rubble:
		if g.p.pick {
			g.terrain[ny][nx] = .Floor
			say(g, "DUG")
			play(g, .Crumble)
			end_turn(g)
		} else {
			say(g, "RUBBLE")
			play(g, .Nope)
		}
		return
	case .Gate:
		if !gate_open(g) {
			say(g, "GATE")
			play(g, .Bump)
			return
		}
	case .One_Way_N, .One_Way_S, .One_Way_W, .One_Way_E:
		if !one_way_allows(t, dx, dy) {
			say(g, "ONE WAY")
			play(g, .Bump)
			return
		}
	}
	if g.block[ny][nx] {
		bx, by := nx + dx, ny + dy
		if !block_can_enter(g, bx, by) {
			play(g, .Bump)
			return
		}
		g.block[ny][nx] = false
		bt := g.terrain[by][bx]
		if bt == .Pit || bt == .Hidden_Pit {
			g.terrain[by][bx] = .Filled_Pit
			say(g, "FILLED")
		} else {
			g.block[by][bx] = true
		}
		play(g, .Push)
	}
	left := g.terrain[g.y][g.x]
	ox, oy := g.x, g.y
	g.x, g.y = nx, ny
	if t == .Fake_Wall {
		reveal_secret(g, nx, ny)
	}
	if left == .Crumble {
		g.terrain[oy][ox] = .Pit
		play(g, .Crumble)
	}
	if t == .Pit || t == .Hidden_Pit {
		g.terrain[ny][nx] = .Pit
		die(g, "FELL")
		return
	}
	// Walking into an arrow is as bad as an arrow walking into you (else the two swap cells).
	for &a in g.arrows {
		if a.live && a.x == nx && a.y == ny {
			a.live = false
			die(g, "SHOT")
			return
		}
	}
	pick_up(g)
	if t == .Stairs {
		clear_level(g)
		return
	}
	end_turn(g)
}

one_way_allows :: proc(t: Terrain, dx, dy: int) -> bool {
	#partial switch t {
	case .One_Way_N:
		return dy == -1
	case .One_Way_S:
		return dy == 1
	case .One_Way_W:
		return dx == -1
	case .One_Way_E:
		return dx == 1
	}
	return true
}

block_can_enter :: proc(g: ^Game, x, y: int) -> bool {
	if solid(g, x, y) || monster_at(g, x, y) >= 0 || item_at(g, x, y) >= 0 {
		return false
	}
	#partial switch g.terrain[y][x] {
	case .Floor, .Plate, .Spikes, .Crumble, .Hidden_Pit, .Pit, .Filled_Pit, .Gate:
		return true
	}
	return false
}

attack :: proc(g: ^Game, m: ^Monster) {
	dmg := 1 + g.p.sword
	m.hp -= dmg
	play(g, .Hit)
	if m.hp <= 0 {
		slay(g, m)
		say(g, "SLAIN")
	} else {
		say_num(g, "HIT ", dmg)
	}
}

slay :: proc(g: ^Game, m: ^Monster) {
	m.dead = true
	g.run[g.level].slain += {m.id}
	play(g, .Slain)
	if m.carry != .None {
		add_item(g, m.carry, m.x, m.y, MAX_ITEMS + m.id)
	}
}

pick_up :: proc(g: ^Game) {
	for i in 0 ..< g.item_count {
		it := &g.items[i]
		if it.taken || it.x != g.x || it.y != g.y || it.kind == .Sign {
			continue
		}
		taken := true
		switch it.kind {
		case .None, .Sign:
			taken = false
		case .Coin:
			g.p.money += COIN_VALUE
			say_num(g, "+$", COIN_VALUE, YELLOW)
			play(g, .Coin)
		case .Key_Yellow, .Key_Red, .Key_Blue:
			g.p.keys[int(it.kind) - int(Item_Kind.Key_Yellow)] += 1
			say(g, "GOT KEY", YELLOW)
			play(g, .Key)
		case .Gem:
			say(g, "GEM!", YELLOW)
			play(g, .Gem)
		case .Potion:
			if g.p.hp >= MAX_HP {
				say(g, "FULL")
				taken = false
			} else {
				g.p.hp = min(MAX_HP, g.p.hp + POTION_HEAL)
				say_num(g, "+", POTION_HEAL, YELLOW)
				play(g, .Potion)
			}
		case .Oneup:
			if g.lives >= MAX_LIVES {
				say(g, "FULL")
				taken = false
			} else {
				g.lives += 1
				say(g, "1UP", YELLOW)
				play(g, .Oneup)
			}
		case .Sword:
			g.p.sword = min(MAX_TIER, g.p.sword + 1)
			say(g, TIER_NAMES_SWORD[g.p.sword], YELLOW)
			play(g, .Item)
		case .Shield:
			g.p.shield = min(MAX_TIER, g.p.shield + 1)
			say(g, TIER_NAMES_SHIELD[g.p.shield], YELLOW)
			play(g, .Item)
		case .Pick:
			g.p.pick = true
			say(g, "PICK", YELLOW)
			play(g, .Item)
		case .Lamp:
			g.p.lamp = true
			say(g, "LAMP", YELLOW)
			play(g, .Item)
		case .Bomb:
			g.p.bombs += 1
			say(g, "BOMB", YELLOW)
			play(g, .Item)
		}
		if taken {
			it.taken = true
			g.run[g.level].taken += {it.id}
		}
	}
}

TIER_NAMES_SWORD := [MAX_TIER + 1]string{"", "SWORD", "SWORD+", "SWORD++"}
TIER_NAMES_SHIELD := [MAX_TIER + 1]string{"", "SHIELD", "SHIELD+", "SHIELD++"}

throw_bomb :: proc(g: ^Game) {
	if g.p.bombs <= 0 {
		say(g, "NO BOMB")
		play(g, .Nope)
		return
	}
	g.p.bombs -= 1
	say(g, "BOOM", RED)
	play(g, .Crusher)
	DIRS := [4][2]int{{0, -1}, {0, 1}, {-1, 0}, {1, 0}}
	for d in DIRS {
		x, y := g.x + d.x, g.y + d.y
		if !in_room(x, y) {
			continue
		}
		if g.terrain[y][x] == .Cracked_Wall {
			g.terrain[y][x] = .Floor
		}
		if mi := monster_at(g, x, y); mi >= 0 {
			slay(g, &g.monsters[mi])
		}
	}
	end_turn(g)
}

clear_level :: proc(g: ^Game) {
	play(g, .Clear)
	if g.level + 1 >= LEVEL_COUNT {
		g.banked = g.run
		g.phase = .Won
		g.page = WON_PAGE
		return
	}
	enter_level(g, g.level + 1)
}

// --- everyone else's turn -------------------------------------------------------------------------

end_turn :: proc(g: ^Game) {
	monsters_act(g)
	if g.phase != .Play {
		return
	}
	g.turn += 1
	run_traps(g)
}

monsters_act :: proc(g: ^Game) {
	for i in 0 ..< g.monster_count {
		m := &g.monsters[i]
		if m.dead {
			continue
		}
		if abs(m.x - g.x) + abs(m.y - g.y) == 1 {
			dmg := max(1, MONSTER_ATTACK[m.kind] - g.p.shield)
			g.p.hp -= dmg
			play(g, .Ouch)
			say_num(g, "OUCH -", dmg, RED)
			if g.p.hp <= 0 {
				g.p.hp = 0
				die(g, "EATEN")
				return
			}
			continue
		}
		switch m.kind {
		case .Slime:
			nx, ny := m.x + m.dx, m.y + m.dy
			if monster_can_enter(g, m, nx, ny) {
				m.x, m.y = nx, ny
			} else {
				m.dx, m.dy = -m.dx, -m.dy
			}
		case .Ghost:
			ghost_step(g, m)
		case .Eye:
		}
	}
}

// A ghost steps toward the player along the longer axis first, then the shorter; it does not
// mind pits, and falls in.
ghost_step :: proc(g: ^Game, m: ^Monster) {
	ddx, ddy := g.x - m.x, g.y - m.y
	sx := 1 if ddx > 0 else (-1 if ddx < 0 else 0)
	sy := 1 if ddy > 0 else (-1 if ddy < 0 else 0)
	tries: [2][2]int
	if abs(ddx) >= abs(ddy) {
		tries = {{sx, 0}, {0, sy}}
	} else {
		tries = {{0, sy}, {sx, 0}}
	}
	for d in tries {
		if d.x == 0 && d.y == 0 {
			continue
		}
		nx, ny := m.x + d.x, m.y + d.y
		if monster_can_enter(g, m, nx, ny) {
			m.x, m.y = nx, ny
			t := g.terrain[ny][nx]
			if t == .Pit || t == .Hidden_Pit {
				g.terrain[ny][nx] = .Pit
				slay(g, m)
				say(g, "IT FELL")
			}
			return
		}
	}
}

run_traps :: proc(g: ^Game) {
	// Arrows in flight move a cell.
	for &a in g.arrows {
		if !a.live {
			continue
		}
		a.x += a.dx
		a.y += a.dy
		arrow_hits(g, &a)
	}
	// Slots fire.
	if g.turn % ARROW_PERIOD == 0 {
		for y in 0 ..< ROOM {
			for x in 0 ..< ROOM {
				if g.terrain[y][x] != .Slot {
					continue
				}
				dx, dy := facing(g, x, y)
				if dx == 0 && dy == 0 {
					continue
				}
				for &a in g.arrows {
					if !a.live {
						a = Arrow{x + dx, y + dy, dx, dy, true}
						play(g, .Arrow)
						arrow_hits(g, &a)
						break
					}
				}
			}
		}
	}
	if g.phase != .Play {
		return
	}
	// Spikes and flames.
	up := spikes_up(g.turn)
	if fire_on(g.turn) {
		play(g, .Fire)
	}
	for i in 0 ..< g.monster_count {
		m := &g.monsters[i]
		if m.dead {
			continue
		}
		if (up && g.terrain[m.y][m.x] == .Spikes) || burning(g, m.x, m.y) {
			slay(g, m)
		}
	}
	if up && g.terrain[g.y][g.x] == .Spikes {
		die(g, "SPIKED")
	} else if burning(g, g.x, g.y) {
		die(g, "BURNT")
	}
}

arrow_hits :: proc(g: ^Game, a: ^Arrow) {
	if solid(g, a.x, a.y) {
		a.live = false
		return
	}
	if mi := monster_at(g, a.x, a.y); mi >= 0 {
		slay(g, &g.monsters[mi])
		a.live = false
		return
	}
	if a.x == g.x && a.y == g.y && g.phase == .Play {
		a.live = false
		die(g, "SHOT")
	}
}

// Gems found so far (this run) in the block of levels that holds the current one, and how many
// the block has.
gems_in_block :: proc(g: ^Game) -> (found, total: int) {
	b := g.level / BLOCK_LEVELS
	for li in b * BLOCK_LEVELS ..< min((b + 1) * BLOCK_LEVELS, LEVEL_COUNT) {
		id := 0
		for y in 0 ..< ROOM {
			row := LEVELS[li].rows[y]
			for x in 0 ..< ROOM {
				ch := row[x]
				if is_item_char(ch) {
					if ch == '*' {
						total += 1
						if id in g.run[li].taken {
							found += 1
						}
					}
					id += 1
				}
			}
		}
	}
	return
}

is_item_char :: proc(ch: u8) -> bool {
	switch ch {
	case '$', '*', '+', '1', '/', ')', 't', 'L', 'o', '?', 'y', 'r', 'b':
		return true
	}
	return false
}
