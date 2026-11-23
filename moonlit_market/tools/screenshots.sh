#!/usr/bin/env bash
# 가상 화면(Xvfb)에서 게임을 자동 플레이하며 스크린샷 저장
# 사용: tools/screenshots.sh [출력 폴더]   (기본: ./screenshots)
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="$(realpath -m "${1:-screenshots}")"
mkdir -p "$OUT"
GODOT="${GODOT:-$(bash tools/setup_godot.sh)}"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
xvfb-run -a -s "-screen 0 720x1280x24" "$GODOT" --path . --rendering-driver opengl3 \
  --resolution 720x1280 --audio-driver Dummy res://tools/capture.tscn -- --test --out="$OUT" 2>&1 \
  | grep -E "saved|CAPTURE_DONE|SCRIPT ERROR"
