#!/usr/bin/env bash
# Kunlik deploy: kalitlar .deploy.env dan (git'ga tushmaydi):
#   GEMINI_KEY=... GROQ_KEY=... CLAUDE_KEY=...
set -e
cd "$(dirname "$0")"
DEFINES=""
if [ -f .deploy.env ]; then
  while IFS='=' read -r k v; do
    [ -z "$k" ] && continue
    case "$k" in \#*) continue;; esac
    DEFINES="$DEFINES --dart-define=$k=$v"
  done < .deploy.env
fi
flutter build web --release --no-wasm-dry-run $DEFINES < /dev/null
cd build/web && vercel --prod --yes --archive=tgz < /dev/null
