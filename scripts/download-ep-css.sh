#!/bin/sh
# 从 cjxt 仓库下载预编译的 Element Plus 样式
# 在项目根目录（有 cjpm.toml）执行

set -e

if [ ! -f "cjpm.toml" ]; then
  echo "error: 请在项目根目录（包含 cjpm.toml）执行此脚本" >&2
  exit 1
fi

OUT_DIR="public/css"

# atomgit raw 地址（若文件同步完成可用）
# URL="https://raw.atomgit.com/ystyle/cjxt/raw/master/examples/public/css/element-plus.css"
# GitHub raw 地址（兜底）
URL="https://raw.githubusercontent.com/ystyle/cjxt/master/examples/public/css/element-plus.css"

mkdir -p "$OUT_DIR"
curl -sL "$URL" -o "${OUT_DIR}/element-plus.css"

if [ ! -s "${OUT_DIR}/element-plus.css" ]; then
  echo "error: download failed" >&2
  exit 1
fi

echo "downloaded Element Plus styles to ${OUT_DIR}/element-plus.css ($(wc -c < "${OUT_DIR}/element-plus.css") bytes)"
