#!/usr/bin/env bash
# 웹(HTML5) 빌드. 결과:
#   build/web/       — 일반 웹 서버용 (python3 -m http.server 로 바로 실행 가능)
#   build/artifact/  — claude.ai 아티팩트용 (wasm 을 15MB 이하 조각으로 분할, 로더 포함)
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$(bash tools/setup_godot.sh)}"
VER="$("$GODOT" --version | sed -E 's/^([0-9]+\.[0-9]+(\.[0-9]+)?)\.stable.*/\1.stable/')"
TPL="$HOME/.local/share/godot/export_templates/$VER"
if [ ! -f "$TPL/web_nothreads_release.zip" ]; then
  echo "웹 내보내기 템플릿 설치 중 (약 1.2GB 다운로드, 1회)..." >&2
  TMP="$(mktemp -d)"
  TAG="${VER%.stable}-stable"
  curl -fsSL -o "$TMP/t.tpz" "https://github.com/godotengine/godot/releases/download/$TAG/Godot_v${TAG}_export_templates.tpz"
  unzip -q -o "$TMP/t.tpz" 'templates/web_nothreads_release.zip' 'templates/version.txt' -d "$TMP"
  mkdir -p "$TPL" && cp "$TMP"/templates/* "$TPL/" && rm -rf "$TMP"
fi
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
rm -rf build/web build/artifact && mkdir -p build/web build/artifact
"$GODOT" --headless --path . --export-release "Web" build/web/index.html
python3 - <<'PY'
import json, re, os
web, art = 'build/web', 'build/artifact'
html = open(f'{web}/index.html', encoding='utf-8').read()
config = json.loads(re.search(r'const GODOT_CONFIG = (\{.*?\});', html).group(1))
config['ensureCrossOriginIsolationHeaders'] = False
config.pop('serviceWorker', None)
wasm = open(f'{web}/index.wasm', 'rb').read()
CHUNK = 14 * 1024 * 1024
parts = []
for i in range(0, len(wasm), CHUNK):
    name = f'index.part{len(parts)}.wasm'
    open(f'{art}/{name}', 'wb').write(wasm[i:i + CHUNK])
    parts.append(name)
# 아티팩트는 .pck 형식을 게시하지 않으므로 .wasm 이름으로 올리고 로더에서 연결한다
open(f'{art}/index.pck.wasm', 'wb').write(open(f'{web}/index.pck', 'rb').read())
for f in ['index.audio.worklet.js', 'index.audio.position.worklet.js']:
    open(f'{art}/{f}', 'wb').write(open(f'{web}/{f}', 'rb').read())
page = open('tools/web_shell.html', encoding='utf-8').read()
page = (page.replace('__PARTS__', json.dumps(parts)).replace('__TOTAL__', str(len(wasm)))
        .replace('__CONFIG__', json.dumps(config, ensure_ascii=False))
        .replace('__GODOT_JS__', open(f'{web}/index.js', encoding='utf-8').read()))
open(f'{art}/index.html', 'w', encoding='utf-8').write(page)
print('artifact files:', sorted(os.listdir(art)))
PY
