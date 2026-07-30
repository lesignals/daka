#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT_DIR"

/usr/bin/swift format lint \
    --configuration "$ROOT_DIR/.swift-format" \
    --recursive \
    --parallel \
    --strict \
    "$ROOT_DIR/Sources" \
    "$ROOT_DIR/Tests" \
    "$ROOT_DIR/Package.swift"

for script in "$ROOT_DIR"/scripts/*.sh; do
    /bin/zsh -n "$script"
done

/usr/bin/git diff --check

print "Lint checks passed"
