#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FILE="$ROOT/Packages/PrismCore/Sources/PrismDaemonCore/PosixSpawnPackageToolRunner.swift"

if [ ! -f "$FILE" ]; then
  echo "ERROR: missing PosixSpawnPackageToolRunner.swift"
  exit 1
fi

# Darwin imports posix_spawn_file_actions_t as an opaque optional handle.
# A direct posix_spawn_file_actions_t() initializer compiles on Glibc but fails on Xcode/Darwin.
if ! grep -q '#if canImport(Darwin)' "$FILE" || \
   ! grep -q 'var actions: posix_spawn_file_actions_t?' "$FILE"; then
  echo "ERROR: Darwin posix_spawn file actions must use an optional opaque handle."
  exit 1
fi

if ! grep -q '#else' "$FILE" || \
   ! grep -q 'var actions = posix_spawn_file_actions_t()' "$FILE"; then
  echo "ERROR: Glibc posix_spawn file actions initializer is missing."
  exit 1
fi

echo "Darwin/Glibc posix_spawn file-actions contract OK."
