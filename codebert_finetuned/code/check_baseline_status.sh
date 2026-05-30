#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

OUTPUT_DIR="saved_models/codebert-finetuned"
TRAIN_LOG="logs/train.log"
EVAL_LOG="logs/evaluate.log"

echo "== Time =="
date

echo
echo "== Baseline Process =="
pgrep -fl "run.py --output_dir=../saved_models/codebert-finetuned|run.py --output_dir ../saved_models/codebert-finetuned" || echo "No active baseline process"

echo
echo "== Artifacts =="
[[ -f "$OUTPUT_DIR/checkpoint-best-acc/model.bin" ]] && echo "checkpoint-best-acc/model.bin: FOUND" || echo "checkpoint-best-acc/model.bin: MISSING"
[[ -f "$OUTPUT_DIR/predictions.txt" ]] && echo "predictions.txt: FOUND" || echo "predictions.txt: MISSING"
[[ -f "$OUTPUT_DIR/evaluation.json" ]] && echo "evaluation.json: FOUND" || echo "evaluation.json: MISSING"

echo
if [[ -f "$TRAIN_LOG" ]]; then
  echo "== Tail $TRAIN_LOG =="
  tail -n 30 "$TRAIN_LOG"
else
  echo "Training log not found yet: $TRAIN_LOG"
fi

echo
if [[ -f "$EVAL_LOG" ]]; then
  echo "== Tail $EVAL_LOG =="
  tail -n 20 "$EVAL_LOG"
else
  echo "Eval log not found yet: $EVAL_LOG"
fi
