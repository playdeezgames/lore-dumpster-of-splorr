# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

**Lore Dumpster of SPLORR!!**, created November 24, 2026 (GitHub `playdeezgames/lore-dumpster-of-splorr`, private; nothing pushed until the user says "push"). A turn-based puzzle adventure in TRS-80 Color Computer `PMODE 1` style: 128 by 96, four colours (green `#00FF00`, yellow `#FFFF00`, blue `#0000FF`, red `#FF0000`), 8 by 8 cells on a 16 by 12 cell screen (a 12 by 12 room plus a 4-cell text panel of 8 characters by 16 lines, using the Anvil's default 4 by 6 font).

**The design lives in the vault note** `/home/yermom/git/bok-of-splorr/splorr/Games/Lore Dumpster of SPLORR!!.md`, which records every decision the user made (marked "the user") and the agent's accepted proposals. Read it first and keep it current; read the vault's `Home.md` for the standing rules.

Odin compiled to `js_wasm32`, a 128x96 software framebuffer drawn to a canvas at whole-number zoom (vault `Tech/Odin wasm recipe.md`). First playable slice November 24, 2026: three levels.

## Commands

Odin is on `PATH` (`odin`).

```bash
tools/test.sh                  # native tests, wasm checks of both packages, then a real wasm build
tools/build.sh [--size]        # wasm build into build/web (copies web/index.html, sounds.js, lootlocker.js, sfx/)
tools/serve.sh                 # build and serve on http://localhost:${PORT:-8154}/
python3 -I tools/gen_gfx.py    # regenerate gfx.odin, font.odin, sounds.odin and web/sounds.js from art/
odin test src/game -collection:tggd=src -define:ODIN_TEST_THREADS=1 -define:ODIN_TEST_NAMES=game.trace -define:TRACE_LEVEL=2 -define:TRACE_SCRIPT=EEE.S   # print the state after each move of a script on a level (0-based); N S W E . o(bomb) R(restart) ' '(OK) n(no)
```

The browser pane's launch config `lore-dumpster-web` (port 8154, in the vault's `.claude/launch.json`) serves `build/web`; run `tools/build.sh` first. Driving it: dispatch `KeyboardEvent('keydown', {code})` on `window`.

## Architecture

- `src/game/` is the pure rules package (no `core:os`, no `core:fmt`; tests start with `#+build !js`). `game.odin`: the rules, deterministic and turn-based. A turn is the player's action (a bump into a wall costs nothing), then the monsters (adjacent ones attack; slimes patrol and turn back, ghosts step toward the player and fall into pits, eyes stay put), then `turn += 1` and `run_traps` (spikes up when turn % 3 == 2; slots fire an arrow when turn % 4 == 0, which flies a cell a turn; nozzles burn their line when turn % 4 >= 2). Monsters die in traps too. `Record` (taken items, slain monsters, opened doors, as bit sets by reading-order id) is kept per level in `run`; `enter_level` on a checkpoint level (every `BLOCK_LEVELS`) copies `run` to `banked` and stores `cp_player` the first time. A restart or death (`lose_life`) costs a life and puts back `entry_player` and `entry_record`; game over picks a reached checkpoint, refills lives and restores `banked`. `find_secrets` marks cells reachable only through a fake wall; they draw as wall until the player walks through it.
- `levels.odin`: every level as a 12x12 ASCII grid (legend at the top of the file), its intro page, sign pages and what each monster carries; the title, game-over and ending pages. Pages are at most 32 by 15 (tests check). Level grids are in Odin, not yet in Anvil maps.
- `render.odin`: the room (cells 8x8), the 8-column panel (level and turn, HP, money, lives, keys R/Y/B, attack and defence, bombs, pick and lamp, gems in the block, level name, then the last five messages), and full-screen pages. `screen.odin`: framebuffer, palette, text, a no-allocation `Text` builder.
- Generated, never hand-edit: `gfx.odin` (the `Gfx` enum follows the Anvil tilesets' image order), `font.odin`, `sounds.odin` (the `Sound` enum follows the Anvil world's sound order; `web/sounds.js` lists the WAVs in the same order).
- `src/web/web.odin` (`#+build js`) only draws after a command and passes sounds; `web/index.html` maps arrows/WASD, Space or `.` (wait, or go on), Enter/Y (OK), B (bomb), R (restart), Esc/N/Backspace (no), F (feedback form), the gamepad and touch pads onto the `Command` order. There is no save yet.
- Not built yet (in the design): shop, bonus levels, crushers, boulders, first-pickup pages, the LORE book, saves, levels 4 to 30.

## Art and sound (anvil MCP)

The world is authored with the `anvil` MCP tools: world file `~/anvil-worlds/lore-dumpster.json`, exported to `art/lore-dumpster.json` (the game reads the export). Palette: index 0 is the transparent key (never a drawn colour), 1 green, 2 yellow, 3 blue, 4 red; indices 5 to 15 are unused (the "twelve stolen colours" of the lore). Tile size 8 by 8.

- Open the world with `world_open` (or `world_new`) before editing. Nothing reaches disk until `world_save`; `world_open` refuses to replace unsaved changes unless `discard: true`, and saving over another file needs `overwrite: true`.
- Name things, never index them. A refused edit explains why; read the message and adjust rather than retrying.
- Look at what you built (`render_tile`, `render_sprite`, `render_map`) before saving. After any change, `world_save` and `world_export` to `art/lore-dumpster.json`.
- **What is in the world (November 24, 2026):** tileset `terrain` (29 opaque tiles: floor, wall, wall_slot/nozzle/seam/cracked/fake, alcove, crusher_shut, floor_cracked, floor_crumble, spikes_down/up, plate, plate_down, boulder_trigger, pit, pit_filled, block, rubble, stairs, door_yellow/red/blue, gate, arrow_up/down/left/right), terrain set `dungeon` with tags `solid`, `deadly`, `trap`, `door`, `pushable`, `exit`; tileset `sprites` and sprite set `things` (26: hero, slime, ghost, eye, key_yellow/red/blue, coin, gem, potion, oneup, sword1-3, shield1-3, pick, lamp, bomb, sign, shopkeeper, arrow_h, arrow_v, flame, boulder; transparent 0); 25 sounds (coin, key, item, gem, oneup, potion, door, bump, push, hit, ouch, slain, dead, gameover, trap_click, fire, arrow, crusher, boulder, crumble, clear, checkpoint, buy, nope, page); map `swatch`, a 12 by 12 test room showing every terrain.
- After changing art: `world_save`, `world_export` to `art/lore-dumpster.json`, then `python3 -I tools/gen_gfx.py`; after changing sounds also `sound_export` each to `web/sfx/<name>.wav`.
- `python3 -I tools/preview_sheet.py art/lore-dumpster.json build/sprites.png 8` draws every sprite on the floor tile as a contact sheet (stdlib only).
- Traps have a subtle clue at rest (a pixel or two, in floor or wall colours), never a warning; red is for a trap going off. Yellow keys and doors need blue detail to read on the green floor.

## Standing rules (full text in the vault's `Home.md`)

- "Push" means `git push`; "ship" means itch.io. Neither unless the user says that word. Ships go through Coxswain (one a day).
- GitHub Pages is the default for every Odin/wasm game; making the repo public and enabling Pages is the user's call.
- Anything an AI agent posts on itch.io says so.
- Do not describe or "fix" the user's decided design as a problem.
