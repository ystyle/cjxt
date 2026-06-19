#!/bin/sh
# 编译 Element Plus 组件 SCSS
# 输出到 public/css/element-plus.css（项目根 + examples 各一份）

set -e
IN="public/scss/element-plus/element-plus.scss"
SASS_FLAGS="--load-path=public/scss/element-plus"
OUT_ROOT="public/css/element-plus.css"
OUT_EXAMPLES="examples/public/css/element-plus.css"

mkdir -p "$(dirname "$OUT_ROOT")" "$(dirname "$OUT_EXAMPLES")"
sass "$IN" "$OUT_ROOT" $SASS_FLAGS
cp "$OUT_ROOT" "$OUT_EXAMPLES"
echo "compiled Element Plus styles to $OUT_ROOT and $OUT_EXAMPLES ($(wc -c < "$OUT_ROOT") bytes)"
