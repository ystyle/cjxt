#!/bin/sh
# 编译 Element Plus 组件 SCSS
# 输出到 examples/public/css/element-plus.css 和 public/css/element-plus.css

set -e
IN="public/scss/element-plus/element-plus.scss"
SASS_FLAGS="--load-path=public/scss/element-plus"
OUT="examples/public/css/element-plus.css"
OUT2="public/css/element-plus.css"

mkdir -p "$(dirname "$OUT")"
mkdir -p "$(dirname "$OUT2")"
sass "$IN" "$OUT" $SASS_FLAGS
cp "$OUT" "$OUT2"
echo "compiled Element Plus styles to $OUT and $OUT2 ($(wc -c < "$OUT") bytes)"
