#!/usr/bin/env bash
# Tests, the size build, then copies it into docs/ for GitHub Pages (served from main /docs).
# Never commits or pushes.
set -euo pipefail
cd "$(dirname "$0")/.."
tools/test.sh
tools/build.sh --size >/dev/null
rm -rf docs
mkdir docs
cp -r build/web/. docs/
touch docs/.nojekyll
du -sh docs
