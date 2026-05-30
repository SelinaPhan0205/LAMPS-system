#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

MODEL_ID="${1:-your-username/codebert-vuln-baseline}"
INPUT_TEXT="${2:-def add(a, b): return a + b}"

CONDA_ENV_NAME="${CONDA_ENV_NAME:-imrenv}"
PYTHON_BIN="${PYTHON_BIN:-/opt/homebrew/Caskroom/miniconda/base/envs/${CONDA_ENV_NAME}/bin/python}"

if [[ ! -x "$PYTHON_BIN" ]]; then
  echo "Python binary not found: $PYTHON_BIN"
  echo "Set PYTHON_BIN to your environment Python path."
  exit 1
fi

"$PYTHON_BIN" code/infer_from_hf.py \
  --model_id "$MODEL_ID" \
  --text "$INPUT_TEXT"
