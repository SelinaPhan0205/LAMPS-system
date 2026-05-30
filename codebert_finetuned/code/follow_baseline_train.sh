#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

TRAIN_LOG="logs/train.log"

while [[ ! -f "$TRAIN_LOG" ]]; do
  echo "Waiting for log file: $TRAIN_LOG"
  sleep 1
done

echo "Tailing $TRAIN_LOG"
tail -f "$TRAIN_LOG"
