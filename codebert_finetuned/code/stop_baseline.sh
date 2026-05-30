#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

PID_FILE="logs/baseline.pid"

if [[ ! -f "$PID_FILE" ]]; then
  echo "No PID file found at $PID_FILE"
  exit 0
fi

pid="$(cat "$PID_FILE" || true)"
if [[ -z "$pid" ]]; then
  echo "PID file is empty: $PID_FILE"
  rm -f "$PID_FILE"
  exit 0
fi

if kill -0 "$pid" 2>/dev/null; then
  kill -TERM "$pid"
  echo "Sent SIGTERM to baseline launcher PID $pid"
else
  echo "Process $pid is not running"
fi

rm -f "$PID_FILE"
