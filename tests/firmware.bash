#!/usr/bin/env bash
set -euo pipefail

: "${IDF_PATH:?set IDF_PATH}"
: "${IDF_PYTHON_ENV_PATH:?set IDF_PYTHON_ENV_PATH}"
: "${TEMPLATE_PATH:?set TEMPLATE_PATH}"
: "${TARGET:?set TARGET}"

project="$TMPDIR/project-$TARGET"
mkdir -p "$project"
cp -R "$TEMPLATE_PATH"/. "$project/"
(
  cd "$project"
  "$IDF_PYTHON_ENV_PATH/bin/python" "$IDF_PATH/tools/idf.py" set-target "$TARGET"
  "$IDF_PYTHON_ENV_PATH/bin/python" "$IDF_PATH/tools/idf.py" build
  "$IDF_PYTHON_ENV_PATH/bin/python" "$IDF_PATH/tools/idf.py" size
)
