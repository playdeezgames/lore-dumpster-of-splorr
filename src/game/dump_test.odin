#+build !js
package game

import "core:os"
import "core:testing"

DUMP_PATH :: #config(DUMP_PATH, "")
DUMP_LEVEL :: #config(DUMP_LEVEL, 0)
DUMP_SCRIPT :: #config(DUMP_SCRIPT, "")

// Renders one frame natively as a 128x96 PPM: a level (0-based) after a script (see `run`), or the
// title page with DUMP_LEVEL=-1.
// odin test src/game -collection:tggd=src -define:ODIN_TEST_NAMES=game.dump -define:DUMP_PATH=/tmp/x.ppm -define:DUMP_LEVEL=0 -define:DUMP_SCRIPT=SS
@(test)
dump :: proc(t: ^testing.T) {
	if DUMP_PATH == "" {
		return
	}
	g := new(Game)
	defer free(g)
	f := new(Frame)
	defer free(f)
	if DUMP_LEVEL < 0 {
		init_game(g)
	} else {
		start(g, DUMP_LEVEL)
		script := DUMP_SCRIPT
		run(g, script)
	}
	draw_game(f, g)
	out := make([dynamic]u8)
	defer delete(out)
	header := "P6 128 96 255\n"
	append(&out, ..transmute([]u8)header)
	for p in f.px {
		c := PALETTE[p if p < 5 else 0]
		append(&out, u8(c >> 16), u8(c >> 8), u8(c))
	}
	testing.expect(t, os.write_entire_file(DUMP_PATH, out[:]) == nil, "could not write the dump")
}
