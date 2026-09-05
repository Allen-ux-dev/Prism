#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PBX="$ROOT/Prism.xcodeproj/project.pbxproj"

if [[ ! -f "$PBX" ]]; then
  echo "Missing project file: $PBX" >&2
  exit 1
fi

DUPLICATES="$(awk '
  {
    line=$0
    sub(/^[ \t]*/, "", line)
    split(line, parts, /[^A-F0-9]/)
    id=parts[1]
    if (length(id) == 24 && line ~ /= *\{/) {
      count[id]++
      lines[id]=(lines[id] ? lines[id] "," NR : NR)
    }
  }
  END {
    for (id in count) {
      if (count[id] > 1) print id " lines " lines[id]
    }
  }
' "$PBX" | sort)"

if [[ -n "$DUPLICATES" ]]; then
  echo "Duplicate Xcode object IDs detected:" >&2
  echo "$DUPLICATES" >&2
  exit 1
fi

echo "Prism Xcode object IDs are unique."
