#!/bin/sh
# 编译 Element Plus 组件 SCSS 到 public/css/element-plus/

set -e
SASS_FLAGS="--load-path=public/scss/element-plus"
CSS_DIR="public/css/element-plus"
SCSS_DIR="public/scss/element-plus"

mkdir -p "$CSS_DIR"

for f in "$SCSS_DIR"/*.scss; do
    name=$(basename "$f" .scss)
    sass "$f" "$CSS_DIR/$name.css" $SASS_FLAGS
    echo "  compiled $name.css"
done
echo "done"
