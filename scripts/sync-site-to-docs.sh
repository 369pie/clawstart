#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SITE_DIR="$ROOT_DIR/site"
DOCS_DIR="$ROOT_DIR/docs"

if [ ! -d "$SITE_DIR" ]; then
    echo "site directory not found: $SITE_DIR" >&2
    exit 1
fi

rm -rf "$DOCS_DIR"
mkdir -p "$DOCS_DIR"
cp -R "$SITE_DIR"/. "$DOCS_DIR"/

cat > "$DOCS_DIR/.nojekyll" <<'EOF'

EOF

echo "Synced site/ -> docs/ for GitHub Pages branch deployment."
