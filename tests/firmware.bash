#!/usr/bin/env bash
set -euo pipefail

: "${IDF_PATH:?set IDF_PATH}"
: "${TEMPLATE_PATH:?set TEMPLATE_PATH}"
: "${TARGET:?set TARGET}"

project="$TMPDIR/project-$TARGET"
mkdir -p "$project"
cp -R "$TEMPLATE_PATH"/. "$project/"
(
  cd "$project"
  idf.py set-target "$TARGET"
  idf.py build
  idf.py size
)
