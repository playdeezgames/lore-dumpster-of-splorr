# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

**Lore Dumpster of SPLORR!!**, created November 24, 2026 (private, local; no GitHub remote yet). A turn-based puzzle adventure in TRS-80 Color Computer `PMODE 1` style: 128 by 96, four colours (green `#00FF00`, yellow `#FFFF00`, blue `#0000FF`, red `#FF0000`), 8 by 8 cells on a 16 by 12 cell screen (a 12 by 12 room plus a 4-cell text panel of 8 characters by 16 lines, using the Anvil's default 4 by 6 font).

**The design lives in the vault note** `/home/yermom/git/bok-of-splorr/splorr/Games/Lore Dumpster of SPLORR!!.md`, which records every decision the user made (marked "the user") and the agent's accepted proposals. Read it first and keep it current; read the vault's `Home.md` for the standing rules.

No code yet. Planned stack: Odin compiled to `js_wasm32`, a software framebuffer drawn to a canvas (vault `Tech/Odin wasm recipe.md`).

## Art and sound (anvil MCP)

The world is authored with the `anvil` MCP tools: world file `~/anvil-worlds/lore-dumpster.json`, exported to `art/lore-dumpster.json` (the game reads the export). Palette: index 0 is the transparent key (never a drawn colour), 1 green, 2 yellow, 3 blue, 4 red; indices 5 to 15 are unused (the "twelve stolen colours" of the lore). Tile size 8 by 8.

- Open the world with `world_open` (or `world_new`) before editing. Nothing reaches disk until `world_save`; `world_open` refuses to replace unsaved changes unless `discard: true`, and saving over another file needs `overwrite: true`.
- Name things, never index them. A refused edit explains why; read the message and adjust rather than retrying.
- Look at what you built (`render_tile`, `render_sprite`, `render_map`) before saving. After any change, `world_save` and `world_export` to `art/lore-dumpster.json`.
- Traps have a subtle clue at rest (a pixel or two, in floor or wall colours), never a warning; red is for a trap going off. Yellow keys and doors need blue detail to read on the green floor.

## Standing rules (full text in the vault's `Home.md`)

- "Push" means `git push`; "ship" means itch.io. Neither unless the user says that word. Ships go through Coxswain (one a day).
- GitHub Pages is the default for every Odin/wasm game; making the repo public and enabling Pages is the user's call.
- Anything an AI agent posts on itch.io says so.
- Do not describe or "fix" the user's decided design as a problem.
