#!/usr/bin/env bash
# Native tests, an odin check of both packages for js_wasm32 (catches stray core:os), then a real wasm build.
set -euo pipefail
cd "$(dirname "$0")/.."
odin test src/game -collection:tggd=src -define:ODIN_TEST_THREADS=1 -vet
odin check src/game -no-entry-point -vet -target:js_wasm32 -collection:tggd=src
odin check src/web -vet -target:js_wasm32 -collection:tggd=src
tools/build.sh >/dev/null
echo "tests ok"
