#!/usr/bin/env bash
# Renders a frame natively to a PNG: tools/dump.sh out.png LEVEL [SCRIPT] [ZOOM]  (LEVEL is 0-based, -1 = title)
set -euo pipefail
cd "$(dirname "$0")/.."
out="$1"; level="$2"; script="${3:-}"; zoom="${4:-3}"
tmp="$(mktemp --suffix=.ppm)"
args=(-define:DUMP_PATH="$tmp" -define:DUMP_LEVEL="$level")
[ -n "$script" ] && args+=(-define:DUMP_SCRIPT="$script")
odin test src/game -collection:tggd=src -define:ODIN_TEST_THREADS=1 -define:ODIN_TEST_NAMES=game.dump "${args[@]}" >/dev/null 2>&1
python3 -I -c "
import sys
from PIL import Image
im = Image.open(sys.argv[1]); z = int(sys.argv[3])
im.resize((im.width * z, im.height * z), Image.NEAREST).save(sys.argv[2])
" "$tmp" "$out" "$zoom"
rm -f "$tmp"
echo "$out"
