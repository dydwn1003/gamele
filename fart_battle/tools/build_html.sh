#!/usr/bin/env bash
# 단일 HTML 버전 빌드 (Godot 없이 브라우저에서 바로 실행). 결과: web/fart_battle.html
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
import json
f = json.load(open('data/fighters.json', encoding='utf-8'))
data = {'player': f['player'], 'opponents': f['opponents'],
        'foods': json.load(open('data/foods.json', encoding='utf-8'))['foods'],
        'balance': json.load(open('data/balance.json', encoding='utf-8'))}
tpl = open('web/template.html', encoding='utf-8').read()
out = tpl.replace('__DATA__', json.dumps(data, ensure_ascii=False))
open('web/fart_battle.html', 'w', encoding='utf-8').write(out)
print('web/fart_battle.html', len(out.encode()), 'bytes')
PY
