#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
VERSION="${1:-0.1.0}"

echo "Building ClawStart release assets for version: $VERSION"

bash "$ROOT_DIR/installer/windows/build.sh" "$VERSION"
bash "$ROOT_DIR/installer/macos/build.sh" "$VERSION" arm64
bash "$ROOT_DIR/installer/macos/build.sh" "$VERSION" x64

cd "$DIST_DIR"

cp "ClawStart-Windows-v${VERSION}.zip" "ClawStart-Windows-latest.zip"
cp "ClawStart-macOS-Apple-Silicon-v${VERSION}.tar.gz" "ClawStart-macOS-Apple-Silicon-latest.tar.gz"
cp "ClawStart-macOS-Intel-v${VERSION}.tar.gz" "ClawStart-macOS-Intel-latest.tar.gz"

echo ""
echo "Built files:"
ls -lh \
  "ClawStart-Windows-v${VERSION}.zip" \
  "ClawStart-Windows-latest.zip" \
  "ClawStart-macOS-Apple-Silicon-v${VERSION}.tar.gz" \
  "ClawStart-macOS-Apple-Silicon-latest.tar.gz" \
  "ClawStart-macOS-Intel-v${VERSION}.tar.gz" \
  "ClawStart-macOS-Intel-latest.tar.gz"
echo ""
echo "Next step:"
echo "  Upload the six files above to the GitHub Release for clawstart."
