#!/bin/sh
# 编译 Element Plus 组件 SCSS（@EmbedString 编译时嵌入）
# 输出到 public/css/element-plus.css

set -e
BASE="public/scss/element-plus/element-plus.scss"
SASS_FLAGS="--load-path=public/scss/element-plus"
OUT="public/css/element-plus.css"

mkdir -p "$(dirname "$OUT")"
sass "$BASE" "$OUT" $SASS_FLAGS
echo "compiled Element Plus styles to $OUT ($(wc -c < "$OUT") bytes)"
