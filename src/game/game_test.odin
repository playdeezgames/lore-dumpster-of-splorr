#+build !js
package game

import "core:testing"

// Runs a script of moves: N S W E, '.' waits, 'o' bombs, 'R' restarts, ' ' is OK on a page.
run :: proc(g: ^Game, script: string) {
	for ch in script {
		switch ch {
		case 'N':
			command(g, .North)
		case 'S':
			command(g, .South)
		case 'W':
			command(g, .West)
		case 'E':
			command(g, .East)
		case '.':
			command(g, .Wait)
		case 'o':
			command(g, .Bomb)
		case 'R':
			command(g, .Restart)
		case ' ':
			command(g, .Ok)
		case 'n':
			command(g, .Cancel)
		}
	}
}

// A new game, past the title and the first lore page, on level `level`.
start :: proc(g: ^Game, level := 0) {
	init_game(g)
	command(g, .Ok)
	if level > 0 {
		enter_level(g, level)
	}
	command(g, .Ok)
}

@(test)
pages_fit :: proc(t: ^testing.T) {
	check :: proc(t: ^testing.T, page: []string) {
		testing.expect(t, len(page) <= PAGE_ROWS - 1, "a page has too many lines")
		for line in page {
			testing.expectf(t, len(line) <= PAGE_COLS, "line too long: %q", line)
		}
	}
	check(t, TITLE_PAGE)
	check(t, WON_PAGE)
	check(t, GAME_OVER_LINES)
	for &lv in LEVELS {
		check(t, lv.intro)
		for s in lv.signs {
			check(t, s)
		}
		testing.expectf(t, len(lv.name) <= PANEL_COLS, "level name too long: %q", lv.name)
	}
}

@(test)
grids_are_whole :: proc(t: ^testing.T) {
	for &lv, li in LEVELS {
		starts, signs := 0, 0
		for row in lv.rows {
			testing.expectf(t, len(row) == ROOM, "level %d: a row is %d wide", li + 1, len(row))
			for ch in transmute([]u8)row {
				if ch == '@' {
					starts += 1
				}
				if ch == '?' {
					signs += 1
				}
			}
		}
		testing.expectf(t, starts == 1, "level %d: %d starts", li + 1, starts)
		testing.expectf(t, signs == len(lv.signs), "level %d: %d signs, %d pages", li + 1, signs, len(lv.signs))
	}
}

@(test)
level_one_walkthrough :: proc(t: ^testing.T) {
	g := new(Game)
	defer free(g)
	start(g)
	testing.expect_value(t, g.phase, Phase.Play)
	run(g, "SSSSEEEEEEESSNNWWNNNEEENEE")
	testing.expect_value(t, g.level, 1)
	testing.expect_value(t, g.phase, Phase.Lore)
	testing.expect_value(t, g.p.money, COIN_VALUE)
	testing.expect_value(t, g.p.keys[0], 0) // the yellow key went into the door
}

@(test)
block_fills_pit :: proc(t: ^testing.T) {
	g := new(Game)
	defer free(g)
	start(g, 1)
	run(g, "SSSSEEEE")
	testing.expect_value(t, g.terrain[5][6], Terrain.Filled_Pit)
	testing.expect_value(t, g.x, 5)
	run(g, "E")
	testing.expect_value(t, g.x, 6)
	testing.expect_value(t, g.phase, Phase.Play)
}

@(test)
hidden_pit_kills_and_restart_costs_a_life :: proc(t: ^testing.T) {
	g := new(Game)
	defer free(g)
	start(g, 1)
	run(g, "SSSSSE")
	testing.expect_value(t, g.phase, Phase.Dead)
	testing.expect_value(t, g.death, "FELL")
	run(g, " ")
	testing.expect_value(t, g.lives, START_LIVES - 1)
	testing.expect_value(t, g.phase, Phase.Play)
	testing.expect_value(t, g.x, 1)
	testing.expect_value(t, g.y, 1)
	testing.expect_value(t, g.terrain[6][2], Terrain.Hidden_Pit) // the level is reset
}

@(test)
restart_puts_the_player_back :: proc(t: ^testing.T) {
	g := new(Game)
	defer free(g)
	start(g)
	run(g, "EE")
	testing.expect_value(t, g.p.money, COIN_VALUE)
	run(g, "Rn")
	testing.expect_value(t, g.phase, Phase.Play)
	testing.expect_value(t, g.lives, START_LIVES)
	run(g, "R ")
	testing.expect_value(t, g.lives, START_LIVES - 1)
	testing.expect_value(t, g.p.money, 0)
	testing.expect(t, item_at(g, 3, 1, .Coin) >= 0, "the coin is back")
}

@(test)
spikes_keep_time :: proc(t: ^testing.T) {
	// Level 2: stand by the spikes at (4, 2) and step on while they are down and off before they rise.
	g := new(Game)
	defer free(g)
	start(g, 1)
	run(g, "SEE") // (3, 2), turn 3
	testing.expect_value(t, g.turn, 3)
	run(g, "E") // turn 4: spikes up on turns 2, 5, 8...
	testing.expect_value(t, g.phase, Phase.Play)
	run(g, ".")
	testing.expect_value(t, g.phase, Phase.Dead)
	testing.expect_value(t, g.death, "SPIKED")
}

@(test)
game_over_returns_to_the_checkpoint :: proc(t: ^testing.T) {
	g := new(Game)
	defer free(g)
	start(g)
	run(g, "EE") // a coin, not banked yet
	for _ in 0 ..< START_LIVES {
		run(g, "R ")
	}
	testing.expect_value(t, g.phase, Phase.Game_Over)
	run(g, " ")
	testing.expect_value(t, g.level, 0)
	testing.expect_value(t, g.lives, START_LIVES)
	testing.expect_value(t, g.p.money, 0)
	testing.expect(t, item_at(g, 3, 1, .Coin) >= 0, "the unbanked coin went back into its level")
}

@(test)
red_key_carries_to_the_next_level :: proc(t: ^testing.T) {
	g := new(Game)
	defer free(g)
	start(g)
	// Down to the secret room through the fake wall at (4, 9) for the red key, then out and up.
	testing.expect(t, g.secret[9][2], "the key room starts secret")
	run(g, "SSSSEEEEEEESSSSWWWWWW")
	testing.expect(t, !g.secret[9][2], "walking through the fake wall uncovers it") // (8, 5), down to (8, 9), west through the fake wall to (2, 9)
	testing.expect_value(t, g.p.keys[1], 1)
}

// Known solutions: if a level change breaks one, the level may no longer be solvable.
@(test)
level_two_walkthrough :: proc(t: ^testing.T) {
	g := new(Game)
	defer free(g)
	start(g, 1)
	run(g, "SEEEENEEEEESSNWWWWW.WWWWSSSEEEEEEEESESSWSSSE")
	testing.expect_value(t, g.level, 2)
	testing.expect_value(t, g.phase, Phase.Lore)
}

@(test)
level_three_walkthrough :: proc(t: ^testing.T) {
	g := new(Game)
	defer free(g)
	start(g, 2)
	run(g, "EEEWWWS..SSoSSSNNNEEEEENEENEW..SSSSSSSSWWWWWWW")
	testing.expect_value(t, g.level, 3)
	testing.expect_value(t, g.phase, Phase.Lore)
}

@(test)
level_four_walkthrough :: proc(t: ^testing.T) {
	g := new(Game)
	defer free(g)
	start(g, 3)
	// Coin, through the crumbling floor, the pick, the slime (it drops the shield), over the
	// crumbling bridge, dig west, dig to the gem and the last coin, down to the stairs.
	run(g, "SSEEEEENEENEESSWSSSWWSSSSSSEWWWNWWWNNNWWWSSSS")
	testing.expect_value(t, g.p.money, 4 * COIN_VALUE)
	testing.expect_value(t, g.p.shield, 1)
	testing.expect(t, g.p.pick, "the pick")
	found, _ := gems_in_block(g)
	testing.expect_value(t, found, 1)
	run(g, "S")
	testing.expect_value(t, g.level, 4)
	testing.expect_value(t, g.phase, Phase.Lore)
}

@(test)
level_five_walkthrough :: proc(t: ^testing.T) {
	g := new(Game)
	defer free(g)
	start(g, 4)
	// Round the hidden pit, both coins in the middle room, the lamp, down the east shaft (the
	// arrows shoot the ghost, which drops the yellow key), the secret room's blue key, the gem
	// behind the blue door, the yellow door, the stairs.
	run(g, "EESEESWWEEEEWWNNEEEEESSSSWSSWWWWWWWWEEESSWWWWEEEEEEEEEE")
	testing.expect(t, g.p.lamp, "the lamp")
	testing.expect_value(t, g.p.money, 4 * COIN_VALUE)
	found, _ := gems_in_block(g)
	testing.expect_value(t, found, 1)
	run(g, "S")
	testing.expect_value(t, g.level, 5)
	testing.expect_value(t, g.phase, Phase.Lore)
}

@(test)
level_six_walkthrough :: proc(t: ^testing.T) {
	g := new(Game)
	defer free(g)
	start(g, 5)
	// The coin, the bomb, across the top jet, the coin, down past both floor jets to the sword,
	// back west to bomb the cracked wall for the gem, east to the eye (it carries a 1UP) and its
	// coin, back past the jet to the stairs.
	run(g, "EESEEEEENEESSSWWESSWWWSSWWEENN.WWWWSSWoSSNNENNEEEEEEEESSSWWWSNENNNW.WWWSSS")
	testing.expect_value(t, g.p.money, 4 * COIN_VALUE)
	testing.expect_value(t, g.p.sword, 1)
	testing.expect_value(t, g.lives, START_LIVES + 1)
	found, _ := gems_in_block(g)
	testing.expect_value(t, found, 1)
	run(g, "S")
	testing.expect_value(t, g.level, 6)
	testing.expect_value(t, g.phase, Phase.Lore)
}

@(test)
level_seven_walkthrough :: proc(t: ^testing.T) {
	g := new(Game)
	defer free(g)
	start(g, 6)
	// The coin, the slime and its room's coin, wait by the crushers, through, the gem and a coin,
	// down the crusher shaft, the last coin, the stairs.
	run(g, "EEESWWSSSSSSSNNNEEE...EEE.EENNNWWWEEESSSSSSSSSWWWW")
	testing.expect_value(t, g.p.money, 4 * COIN_VALUE)
	found, _ := gems_in_block(g)
	testing.expect_value(t, found, 1)
	run(g, "W")
	testing.expect_value(t, g.level, 7)
	testing.expect_value(t, g.phase, Phase.Lore)
}

@(test)
crusher_crushes_and_a_block_jams_it :: proc(t: ^testing.T) {
	// Level 7: (6, 4) and (7, 4) shut on turns 1, 5, 9...
	g := new(Game)
	defer free(g)
	start(g, 6)
	testing.expect(t, is_crusher(g, 6, 4), "between two seams")
	testing.expect(t, !is_crusher(g, 8, 4), "plain walls")
	run(g, "EEESWWSSSSSSSNNNEEEEE") // into (6, 4) on turn 19, (7, 4) on 20, still there on 21
	testing.expect_value(t, g.phase, Phase.Dead)
	testing.expect_value(t, g.death, "CRUSHED")
	g.turn = 1
	testing.expect(t, crusher_shut(g, 6, 4), "shut on turn 1")
	g.block[4][6] = true
	testing.expect(t, !crusher_shut(g, 6, 4), "a block jams it")
}

@(test)
level_eight_walkthrough :: proc(t: ^testing.T) {
	g := new(Game)
	defer free(g)
	start(g, 7)
	// The coin, down to the corridor, onto the raised stone and back up out of the way: the boulder
	// rolls west and fills the pit. Then the coin and the gem by the eye, the room below, the stairs.
	run(g, "EESESSSSEWN......SEEEENNNWEEENNSSWWSSSWWSSWWWWWSSEEEEEEEEENNWWWWNNWWWW")
	testing.expect_value(t, g.terrain[6][3], Terrain.Filled_Pit)
	testing.expect_value(t, g.p.money, 4 * COIN_VALUE)
	found, _ := gems_in_block(g)
	testing.expect_value(t, found, 1)
	run(g, "W")
	testing.expect_value(t, g.level, 8)
	testing.expect_value(t, g.phase, Phase.Lore)
}

@(test)
boulder_squashes :: proc(t: ^testing.T) {
	// Level 8: stand on the raised stone and stay in the boulder's way.
	g := new(Game)
	defer free(g)
	start(g, 7)
	run(g, "EESESSSSE")
	testing.expect(t, boulder_at(g, 10, 6) >= 0, "out of its alcove")
	run(g, "W.....")
	testing.expect_value(t, g.phase, Phase.Dead)
	testing.expect_value(t, g.death, "SQUASHED")
}

@(test)
level_nine_walkthrough :: proc(t: ^testing.T) {
	g := new(Game)
	defer free(g)
	start(g, 8)
	// The block onto the plate opens the gate; the gem past two spikes; both coins; one way down;
	// a coin; the block into the pit; a coin; past two more spikes to the stairs.
	run(g, "ESSEEEEENN.EEEWWWSSSWEEEWWWSSSWWWWSNENEEEEESSSNNNEE..SSS")
	testing.expect_value(t, g.p.money, 4 * COIN_VALUE)
	found, _ := gems_in_block(g)
	testing.expect_value(t, found, 1)
	run(g, "S")
	testing.expect_value(t, g.level, 9)
	testing.expect_value(t, g.phase, Phase.Lore)
}

@(test)
one_way_floor_has_no_way_back :: proc(t: ^testing.T) {
	g := new(Game)
	defer free(g)
	start(g, 8)
	run(g, "ESSEEEESSS") // through the gate, down the one-way floor at (6, 5)
	testing.expect_value(t, g.y, 6)
	run(g, "N")
	testing.expect_value(t, g.y, 6)
}

@(test)
level_ten_walkthrough :: proc(t: ^testing.T) {
	g := new(Game)
	defer free(g)
	start(g, 9)
	// The coin, a bomb, a bomb and a coin, the raised stone (the boulder squashes the slime in the
	// lane and fills the pit), bomb the eye for the yellow key, bomb the cracked wall for the gem,
	// the coin, the fake wall's red key (for later), down the lane, the coin, the crusher, the
	// yellow door, the stairs.
	run(g, "EEESSWWEEEENESSNNNEWSSWWWWWSSSoSSWoSSNNEEEWSSNNWNNNNNEEEEEEESSSSSEWWW.SSEEE")
	testing.expect_value(t, g.p.money, 4 * COIN_VALUE)
	testing.expect_value(t, g.p.keys[1], 1) // the red key goes on to the next block
	found, _ := gems_in_block(g)
	testing.expect_value(t, found, 1)
	run(g, "E")
	testing.expect_value(t, g.phase, Phase.Won)
}

@(test)
floor_jet_burns :: proc(t: ^testing.T) {
	// Level 6: the jet from the nozzle at (8, 7) covers (8, 6) on turns 2 and 3 of every 4.
	g := new(Game)
	defer free(g)
	start(g, 5)
	run(g, "EESEEEEENEESSSWWESSW.")
	testing.expect_value(t, g.phase, Phase.Play)
	run(g, ".")
	testing.expect_value(t, g.phase, Phase.Dead)
	testing.expect_value(t, g.death, "BURNT")
}

@(test)
the_basement_is_dark :: proc(t: ^testing.T) {
	g := new(Game)
	defer free(g)
	start(g, 4)
	testing.expect(t, lit(g, 2, 2), "next to the player")
	testing.expect(t, !lit(g, 3, 1), "two cells away")
	run(g, "EESEENEEEEE")
	testing.expect(t, g.p.lamp, "the lamp")
	testing.expect(t, lit(g, 1, 10), "everything, with the lamp")
}

@(test)
walking_into_an_arrow_shoots_you :: proc(t: ^testing.T) {
	// Level 3: the slot at (0, 3) fires on turn 8; the arrow appears at (1, 3), right under (1, 2).
	g := new(Game)
	defer free(g)
	start(g, 2)
	run(g, "EEEWWWS.")
	testing.expect_value(t, g.turn, 8)
	run(g, "S")
	testing.expect_value(t, g.phase, Phase.Dead)
	testing.expect_value(t, g.death, "SHOT")
}

@(test)
crumbling_floor_holds_once :: proc(t: ^testing.T) {
	g := new(Game)
	defer free(g)
	start(g, 3)
	run(g, "SSEEEEE") // over the crumbling floor at (5, 3), now at (6, 3)
	testing.expect_value(t, g.terrain[3][5], Terrain.Pit)
	run(g, "W")
	testing.expect_value(t, g.phase, Phase.Dead)
	testing.expect_value(t, g.death, "FELL")
}

@(test)
rubble_needs_the_pick :: proc(t: ^testing.T) {
	g := new(Game)
	defer free(g)
	start(g, 3)
	run(g, "SSESS") // (3, 4), under it the rubble at (3, 5)
	testing.expect_value(t, g.y, 4)
	testing.expect_value(t, g.terrain[5][3], Terrain.Rubble)
}

// The whole first block from the title, carrying everything from level to level (so fights take
// fewer blows than in the one-level walkthroughs). The scripts are the browser playthrough's too.
FULL_RUN := [LEVEL_COUNT]string {
	"SSSSEEEEEEESSSSWWWWWWEEEEEENNNNWWNNNEEENEE", // with the red key from the secret room
	"SEEEENEEEEESSNWWWWW.WWWWSSSEEEEEEEESESSWWWWWWWWWWSNEEEEEEEESSSE", // and the red door's gem
	"EEEWWWS..SSoSSSNNNEEEEENEENEW..SSSSSSSSWWWWWWW",
	"SSEEEEENEENEESSWSSSWWSSSSSSEWWWNWWWNNNWWWSSSSS",
	"EESEESWWEEEEWWNNEEEEESSSSWSSWWWWWWWWEEESSWWWWEEEEEEEEEES",
	"EESEEEEENEESSSWWESSWWWSSWWEENN.WWWWSSWoSSNNENNEEEEEEEESSSWWWSNENNNW.WWWSSSS",
	"EEESWWSSS.SSSNNNEEE...EEE.EENNNWWWEEESSSSSSSSSWWWWW", // the sword kills the slime in one blow
	"EESESSSSEWN......SEEEENNNWEEENNSSWWSSSWWSSWWWWWSSEEEEEEEEENNWWWWNNWWWWW",
	"ESSEEEEENN.EEEWWWSSSWEEEWWWSSSWWWWSNENEEEEESSSNNNEE..SSSS",
	"EEESSWWEEEENESSNNNEWSSWWWWWSSSoSSWoSSNNEEEWSSNNWNNNNNEEEEEEESSSSSEWWW.SSEEEE",
}

@(test)
full_run :: proc(t: ^testing.T) {
	g := new(Game)
	defer free(g)
	init_game(g)
	command(g, .Ok) // the title
	for script, i in FULL_RUN {
		testing.expectf(t, g.level == i && g.phase == .Lore, "level %d: on level %d, %v", i + 1, g.level + 1, g.phase)
		command(g, .Ok) // the intro
		run(g, script)
	}
	testing.expect_value(t, g.phase, Phase.Won)
	testing.expect_value(t, g.lives, START_LIVES + 1) // level 6's 1UP, and no deaths
	found, total := gems_in_block(g)
	testing.expect_value(t, found, total)
}
