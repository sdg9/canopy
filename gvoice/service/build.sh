#!/bin/bash
# Compile the Swift TCC wrapper into CanopyGvoice.app/Contents/MacOS/canopy-gvoice.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$SCRIPT_DIR/CanopyGvoice.app"
OUT="$APP_DIR/Contents/MacOS/canopy-gvoice"

mkdir -p "$APP_DIR/Contents/MacOS"
swiftc -O -o "$OUT" "$SCRIPT_DIR/canopy-gvoice.swift"
# Ad-hoc sign so the bundle has a stable code identity for TCC.
codesign --force --sign - "$OUT"
codesign --force --sign - "$APP_DIR"
echo "built $OUT"
