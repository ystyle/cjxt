#!/bin/sh
# 编译 Element Plus 组件 SCSS，追加到 examples/public/css/bundle.css

set -e
IN="public/scss/element-plus/element-plus.scss"
SASS_FLAGS="--load-path=public/scss/element-plus"
BUNDLE="examples/public/css/bundle.css"

TMP=$(mktemp)
mkdir -p "$(dirname "$BUNDLE")"
sass "$IN" "$TMP" $SASS_FLAGS
cat "$TMP" >> "$BUNDLE"
rm "$TMP"
echo "appended Element Plus styles to $BUNDLE ($(wc -c < "$BUNDLE") bytes total)"
