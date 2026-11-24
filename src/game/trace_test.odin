#+build !js
package game

import "core:fmt"
import "core:testing"

TRACE_LEVEL :: #config(TRACE_LEVEL, 1)
TRACE_SCRIPT :: #config(TRACE_SCRIPT, "")

// odin test src/game -collection:tggd=src -define:ODIN_TEST_NAMES=game.trace -define:TRACE_LEVEL=1 -define:TRACE_SCRIPT=SSEE
@(test)
trace :: proc(t: ^testing.T) {
	if TRACE_SCRIPT == "" {
		return
	}
	g := new(Game)
	defer free(g)
	start(g, TRACE_LEVEL)
	script := TRACE_SCRIPT
	for ch, i in script {
		run(g, script[i:i + 1])
		ms: [4]u8
		fmt.printf("%2d %c -> (%d,%d) t%d %v hp%d keys%v", i, ch, g.x, g.y, g.turn, g.phase, g.p.hp, g.p.keys)
		for j in 0 ..< g.monster_count {
			m := &g.monsters[j]
			fmt.printf(" %v(%d,%d)%s", m.kind, m.x, m.y, "x" if m.dead else "")
		}
		for b in g.boulders {
			if b.live {
				fmt.printf(" O(%d,%d)", b.x, b.y)
			}
		}
		fmt.printf(" lvl%d %s\n", g.level, g.death)
		_ = ms
	}
}
