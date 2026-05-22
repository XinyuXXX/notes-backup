#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="/Users/xuxinyu/Desktop/claude/notes-backup"
VAULT="/Users/xuxinyu/Library/Mobile Documents/iCloud~md~obsidian/Documents/Xinyu's Vault"

cd "$REPO_DIR"

rsync -aL --delete --exclude='.DS_Store' --exclude='._*' \
  "$VAULT/raw/clipping/" ./clipping/
rsync -aL --delete --exclude='.DS_Store' --exclude='._*' \
  "$VAULT/wiki/" ./wiki/

git add -A
if git diff --cached --quiet; then
  echo "[$(date '+%F %T')] no changes"
  exit 0
fi

git commit -m "sync $(date '+%F %T')"
git push origin main
echo "[$(date '+%F %T')] pushed"
