#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

mkdir -p logs
LAUNCH_LOG="logs/baseline.launch.log"
PID_FILE="logs/baseline.pid"

if [[ -f "$PID_FILE" ]]; then
  old_pid="$(cat "$PID_FILE" || true)"
  if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
    echo "Baseline already running with PID $old_pid"
    echo "Tail logs/train.log to monitor progress"
    exit 0
  fi
fi

nohup bash ./code/run_baseline_paper.sh >> "$LAUNCH_LOG" 2>&1 &
pid=$!
echo "$pid" > "$PID_FILE"

echo "Started baseline in background."
echo "PID: $pid"
echo "Launch log: $LAUNCH_LOG"
echo "Train log: logs/train.log"
echo "Eval log: logs/evaluate.log"
