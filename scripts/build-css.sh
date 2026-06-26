#!/bin/sh
# 编译 Element Plus 组件 SCSS（@EmbedString 编译时嵌入）
# 输出到 public/css/element-plus.css，并同步到 examples/public/css/element-plus.css
# @EmbedString 按编译器 -p 参数指向的包根目录解析路径，examples/ 下编译需要该文件存在

set -e
BASE="public/scss/element-plus/element-plus.scss"
SASS_FLAGS="--load-path=public/scss/element-plus"
OUT="public/css/element-plus.css"
EXAMPLES_OUT="examples/public/css/element-plus.css"

mkdir -p "$(dirname "$OUT")" "$(dirname "$EXAMPLES_OUT")"
sass "$BASE" "$OUT" $SASS_FLAGS
cp "$OUT" "$EXAMPLES_OUT"
echo "compiled Element Plus styles to $OUT and $EXAMPLES_OUT ($(wc -c < "$OUT") bytes)"
