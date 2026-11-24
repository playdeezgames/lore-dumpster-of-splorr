# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

**Lore Dumpster of SPLORR!!**, created November 24, 2026 (GitHub `playdeezgames/lore-dumpster-of-splorr`, private; nothing pushed until the user says "push"). A turn-based puzzle adventure in TRS-80 Color Computer `PMODE 1` style: 128 by 96, four colours (green `#00FF00`, yellow `#FFFF00`, blue `#0000FF`, red `#FF0000`), 8 by 8 cells on a 16 by 12 cell screen (a 12 by 12 room plus a 4-cell text panel of 8 characters by 16 lines, using the Anvil's default 4 by 6 font).

**The design lives in the vault note** `/home/yermom/git/bok-of-splorr/splorr/Games/Lore Dumpster of SPLORR!!.md`, which records every decision the user made (marked "the user") and the agent's accepted proposals. Read it first and keep it current; read the vault's `Home.md` for the standing rules.

No code yet. Planned stack: Odin compiled to `js_wasm32`, a software framebuffer drawn to a canvas (vault `Tech/Odin wasm recipe.md`).

## Art and sound (anvil MCP)

The world is authored with the `anvil` MCP tools: world file `~/anvil-worlds/lore-dumpster.json`, exported to `art/lore-dumpster.json` (the game reads the export). Palette: index 0 is the transparent key (never a drawn colour), 1 green, 2 yellow, 3 blue, 4 red; indices 5 to 15 are unused (the "twelve stolen colours" of the lore). Tile size 8 by 8.

- Open the world with `world_open` (or `world_new`) before editing. Nothing reaches disk until `world_save`; `world_open` refuses to replace unsaved changes unless `discard: true`, and saving over another file needs `overwrite: true`.
- Name things, never index them. A refused edit explains why; read the message and adjust rather than retrying.
- Look at what you built (`render_tile`, `render_sprite`, `render_map`) before saving. After any change, `world_save` and `world_export` to `art/lore-dumpster.json`.
- **What is in the world (November 24, 2026):** tileset `terrain` (29 opaque tiles: floor, wall, wall_slot/nozzle/seam/cracked/fake, alcove, crusher_shut, floor_cracked, floor_crumble, spikes_down/up, plate, plate_down, boulder_trigger, pit, pit_filled, block, rubble, stairs, door_yellow/red/blue, gate, arrow_up/down/left/right), terrain set `dungeon` with tags `solid`, `deadly`, `trap`, `door`, `pushable`, `exit`; tileset `sprites` and sprite set `things` (26: hero, slime, ghost, eye, key_yellow/red/blue, coin, gem, potion, oneup, sword1-3, shield1-3, pick, lamp, bomb, sign, shopkeeper, arrow_h, arrow_v, flame, boulder; transparent 0); 25 sounds (coin, key, item, gem, oneup, potion, door, bump, push, hit, ouch, slain, dead, gameover, trap_click, fire, arrow, crusher, boulder, crumble, clear, checkpoint, buy, nope, page); map `swatch`, a 12 by 12 test room showing every terrain.
- `python3 -I tools/preview_sheet.py art/lore-dumpster.json build/sprites.png 8` draws every sprite on the floor tile as a contact sheet (stdlib only).
- Traps have a subtle clue at rest (a pixel or two, in floor or wall colours), never a warning; red is for a trap going off. Yellow keys and doors need blue detail to read on the green floor.

## Standing rules (full text in the vault's `Home.md`)

- "Push" means `git push`; "ship" means itch.io. Neither unless the user says that word. Ships go through Coxswain (one a day).
- GitHub Pages is the default for every Odin/wasm game; making the repo public and enabling Pages is the user's call.
- Anything an AI agent posts on itch.io says so.
- Do not describe or "fix" the user's decided design as a problem.
