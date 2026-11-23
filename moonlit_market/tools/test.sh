#!/usr/bin/env bash
# 헤드리스 테스트 실행 (Godot 자동 설치 → 임포트 → 테스트). 종료 코드 0 = 전체 통과
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$(bash tools/setup_godot.sh)}"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . res://tests/test_runner.tscn -- --test
