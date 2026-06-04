#!/usr/bin/env bash
# Push ai-book to https://github.com/maodongya/ai-book.git
# Run from repo root (this directory's parent): requires GitHub auth (SSH or HTTPS).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not a git repository. Run from ai-book after setup." >&2
  exit 1
fi

REMOTE="${AI_BOOK_REMOTE:-https://github.com/maodongya/ai-book.git}"
BRANCH="${AI_BOOK_BRANCH:-main}"

git remote set-url origin "$REMOTE"
git branch -M "$BRANCH" 2>/dev/null || true

echo "==> Pushing to $REMOTE (branch $BRANCH)..."
git push -u origin "$BRANCH"

echo "==> Done: https://github.com/maodongya/ai-book"
