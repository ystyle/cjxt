#!/bin/sh
# 编译 Element Plus 组件 SCSS
# 输出到 examples/public/css/element-plus.css
# public/css/element-plus.css 是软链接

set -e
IN="public/scss/element-plus/element-plus.scss"
SASS_FLAGS="--load-path=public/scss/element-plus"
OUT="examples/public/css/element-plus.css"

mkdir -p "$(dirname "$OUT")"
sass "$IN" "$OUT" $SASS_FLAGS
echo "compiled Element Plus styles to $OUT ($(wc -c < "$OUT") bytes)"
