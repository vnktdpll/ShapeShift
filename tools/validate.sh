#!/usr/bin/env bash
# Deterministic CI-friendly validation for the Godot 4 project.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/Users/vnktdpl/Downloads/Godot 2.app/Contents/MacOS/Godot}"

if [[ ! -x "$GODOT_BIN" ]]; then
  echo "Godot executable not found: $GODOT_BIN" >&2
  exit 2
fi

echo "[VALIDATE] parser/import scan"
SCAN_LOG="$(mktemp)"
trap 'rm -f "$SCAN_LOG"' EXIT
"$GODOT_BIN" --headless --path "$ROOT" --editor --quit 2>&1 | tee "$SCAN_LOG"
if rg -q 'ERROR:|SCRIPT ERROR:|Parse Error:' "$SCAN_LOG"; then
  echo "[VALIDATE] parser/import scan reported errors" >&2
  exit 1
fi
echo "[VALIDATE] deterministic gameplay checks"
"$GODOT_BIN" --headless --path "$ROOT" --script res://tests/test_runner.gd
echo "[VALIDATE] presentation/audio smoke"
"$GODOT_BIN" --headless --path "$ROOT" --script res://tools/audio_smoke.gd
