#!/usr/bin/env bash
# Godot 4.4.1 (Linux x86_64) 를 내려받아 설치한다. 이미 있으면 건너뜀.
# 설치 위치: $GODOT_HOME (기본 ~/.local/share/godot) → 실행 파일 $GODOT_HOME/godot
set -euo pipefail
VERSION="${GODOT_VERSION:-4.4.1-stable}"
GODOT_HOME="${GODOT_HOME:-$HOME/.local/share/godot}"
BIN="$GODOT_HOME/godot"
# PATH 에 같은 버전 godot 이 있으면 그대로 사용 (클라우드 환경 설정 스크립트가 설치한 경우)
if command -v godot >/dev/null 2>&1 && godot --version 2>/dev/null | grep -q "${VERSION%-stable}"; then
  command -v godot; exit 0
fi
if [ -x "$BIN" ] && "$BIN" --version 2>/dev/null | grep -q "${VERSION%-stable}"; then
  echo "$BIN"; exit 0
fi
mkdir -p "$GODOT_HOME"
TMP="$(mktemp -d)"
URL="https://github.com/godotengine/godot/releases/download/${VERSION}/Godot_v${VERSION}_linux.x86_64.zip"
curl -fsSL -o "$TMP/godot.zip" "$URL"
unzip -q -o "$TMP/godot.zip" -d "$TMP"
mv -f "$TMP/Godot_v${VERSION}_linux.x86_64" "$BIN"
chmod +x "$BIN"
rm -rf "$TMP"
"$BIN" --version >&2
echo "$BIN"
