#!/usr/bin/env bash
# Builds and serves the game on http://localhost:${PORT:-8154}/
set -euo pipefail
cd "$(dirname "$0")/.."
tools/build.sh >/dev/null
exec python3 -m http.server "${PORT:-8154}" -d build/web
