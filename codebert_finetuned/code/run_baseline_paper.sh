#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f .env ]]; then
  set -a
  source .env
  set +a
fi

CONDA_ENV_NAME="${CONDA_ENV_NAME:-imrenv}"
if [[ -z "${DATALOADER_NUM_WORKERS:-}" ]]; then
  if [[ "$(uname -s)" == "Darwin" ]]; then
    DATALOADER_NUM_WORKERS=0
  else
    DATALOADER_NUM_WORKERS=4
  fi
fi

PYTHON_BIN="${PYTHON_BIN:-}"
if [[ -z "$PYTHON_BIN" ]]; then
  if [[ -x "/opt/homebrew/Caskroom/miniconda/base/envs/${CONDA_ENV_NAME}/bin/python" ]]; then
    PYTHON_BIN="/opt/homebrew/Caskroom/miniconda/base/envs/${CONDA_ENV_NAME}/bin/python"
  elif command -v conda >/dev/null 2>&1; then
    CONDA_BASE="$(conda info --base 2>/dev/null || true)"
    if [[ -n "$CONDA_BASE" && -x "$CONDA_BASE/envs/${CONDA_ENV_NAME}/bin/python" ]]; then
      PYTHON_BIN="$CONDA_BASE/envs/${CONDA_ENV_NAME}/bin/python"
    fi
  fi
fi

if [[ -z "$PYTHON_BIN" || ! -x "$PYTHON_BIN" ]]; then
  echo "Cannot find Python executable for conda env '${CONDA_ENV_NAME}'."
  echo "Set PYTHON_BIN explicitly or ensure env exists."
  exit 1
fi

mkdir -p logs saved_models/codebert-finetuned
: > logs/train.log
: > logs/evaluate.log

echo "Starting baseline training with original repo settings..."
echo "Training log: logs/train.log"
echo "Evaluate log: logs/evaluate.log"
echo "DataLoader workers: ${DATALOADER_NUM_WORKERS}"
echo "Python executable: ${PYTHON_BIN}"

export PYTHONUNBUFFERED=1
export TOKENIZERS_PARALLELISM="${TOKENIZERS_PARALLELISM:-false}"

cd code

"$PYTHON_BIN" -u run.py \
  --output_dir=../saved_models/codebert-finetuned \
  --model_type=roberta \
  --tokenizer_name=microsoft/codebert-base \
  --model_name_or_path=microsoft/codebert-base \
  --do_train \
  --do_eval \
  --do_test \
  --train_data_file=../data/train.jsonl \
  --eval_data_file=../data/val.jsonl \
  --test_data_file=../data/test.jsonl \
  --epoch 5 \
  --block_size 400 \
  --train_batch_size 16 \
  --eval_batch_size 64 \
  --dataloader_num_workers "${DATALOADER_NUM_WORKERS}" \
  --learning_rate 2e-5 \
  --max_grad_norm 1.0 \
  --evaluate_during_training \
  --seed 123456 2>&1 | tee ../logs/train.log

echo "Running evaluator on test predictions..."
"$PYTHON_BIN" -u ../evaluator/evaluator.py \
  --answers ../data/test.jsonl \
  --predictions ../saved_models/codebert-finetuned/predictions.txt 2>&1 | tee ../logs/evaluate.log

cd "$ROOT_DIR"

"$PYTHON_BIN" - <<'PY'
import ast
import json
from pathlib import Path

output_dir = Path("saved_models/codebert-finetuned")
eval_log = Path("logs/evaluate.log")

lines = [line.strip() for line in eval_log.read_text(encoding="utf-8").splitlines() if line.strip()]
metrics = ast.literal_eval(lines[-1]) if lines else {}

payload = {
    "run_name": "codebert_finetuned_original_settings",
    "config": {
        "max_length": 400,
        "loss": "Binary Cross-Entropy",
        "learning_rate": 2e-5,
        "train_batch_size": 16,
        "eval_batch_size": 64,
        "epochs": 5,
        "seed": 123456,
    },
    "metrics": metrics,
}

(output_dir / "evaluation.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")
print(json.dumps(payload, indent=2))
PY

echo "Baseline run completed with original settings."
