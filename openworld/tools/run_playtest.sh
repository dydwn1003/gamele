#!/bin/bash
# 자동 플레이 테스트: Godot 를 (없으면 내려받아) 가상 화면에서 실행하고 스크린샷을 남긴다.
# 사용법: tools/run_playtest.sh [스크린샷 폴더]   (기본: openworld/.playtest)
set -e
VER=4.5.1-stable
GODOT_DIR="${GODOT_DIR:-$HOME/.cache/godot}"
GODOT="$GODOT_DIR/Godot_v${VER}_linux.x86_64"
PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$PROJECT/.playtest}"

if [ ! -x "$GODOT" ]; then
  mkdir -p "$GODOT_DIR"
  curl -sSL -o "$GODOT_DIR/godot.zip" "https://github.com/godotengine/godot/releases/download/${VER}/Godot_v${VER}_linux.x86_64.zip"
  unzip -o -q "$GODOT_DIR/godot.zip" -d "$GODOT_DIR" && rm "$GODOT_DIR/godot.zip"
fi

mkdir -p "$OUT"
cd "$PROJECT"
# 스크립트 오류 검사 (오류가 있으면 여기서 출력됨)
timeout 180 "$GODOT" --headless --import 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error" -A1 || true
# 이전 저장 파일 삭제 후 실행
rm -f "$HOME/.local/share/godot/app_userdata/"*"/save.json"
SHOT_DIR="$OUT" timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --resolution 1280x720 -s res://tools/playtest.gd 2>&1 \
  | grep -vE "ALSA|Vulkan|VK_|V-Sync|err != OK|audio|ERR_CANT_OPEN|^\s*at: |^\s*$" || true
echo "스크린샷: $OUT"
