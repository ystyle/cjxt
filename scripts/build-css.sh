#!/bin/sh
# 编译 Element Plus 组件 SCSS 为单一 CSS 文件

set -e
OUT="public/css/element-plus/element-plus.css"
IN="public/scss/element-plus/element-plus.scss"
SASS_FLAGS="--load-path=public/scss/element-plus"

mkdir -p "$(dirname "$OUT")"
sass "$IN" "$OUT" $SASS_FLAGS

# 复制到示例项目
mkdir -p examples/public/css/element-plus
cp "$OUT" examples/public/css/element-plus/
echo "compiled $OUT ($(wc -c < "$OUT") bytes)"
