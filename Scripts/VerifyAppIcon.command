#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT/App/Assets.xcassets/AppIcon.appiconset" <<'PY'
import json, struct, sys
from pathlib import Path
folder=Path(sys.argv[1]); data=json.loads((folder/'Contents.json').read_text())
errors=[]
for item in data['images']:
    name=item.get('filename')
    if not name: continue
    path=folder/name
    if not path.exists(): errors.append(f'missing {name}'); continue
    raw=path.read_bytes()[:24]
    if raw[:8] != b'\x89PNG\r\n\x1a\n': errors.append(f'{name}: not PNG'); continue
    width,height=struct.unpack('>II',raw[16:24])
    base=float(item['size'].split('x')[0]); scale=float(item['scale'][:-1]); expected=round(base*scale)
    if (width,height)!=(expected,expected): errors.append(f'{name}: {width}x{height}, expected {expected}x{expected}')
if errors:
    print('ERROR: AppIcon validation failed:'); print('\n'.join(errors)); raise SystemExit(1)
print(f'AppIcon catalog OK ({len(data["images"])} entries).')
PY
