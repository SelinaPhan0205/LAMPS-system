#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f .env ]]; then
  set -a
  source .env
  set +a
fi

if [[ -z "${HF_REPO_ID:-}" ]]; then
  echo "HF_REPO_ID is not set. Set it in .env or as an environment variable."
  exit 1
fi

if [[ -z "${HF_WRITE_TOKEN:-}" ]]; then
  echo "HF_WRITE_TOKEN is not set. Set it in .env or as an environment variable."
  exit 1
fi

CONDA_ENV_NAME="${CONDA_ENV_NAME:-imrenv}"
PYTHON_BIN="${PYTHON_BIN:-/opt/homebrew/Caskroom/miniconda/base/envs/${CONDA_ENV_NAME}/bin/python}"

if [[ ! -x "$PYTHON_BIN" ]]; then
  echo "Python binary not found: $PYTHON_BIN"
  echo "Set PYTHON_BIN to your environment Python path."
  exit 1
fi

extra_args=()
if [[ "${HF_PRIVATE:-false}" == "true" ]]; then
  extra_args+=(--private)
fi

if [[ ${#extra_args[@]} -gt 0 ]]; then
  "$PYTHON_BIN" code/publish_baseline_to_hf.py \
    --repo_id "$HF_REPO_ID" \
    --token "$HF_WRITE_TOKEN" \
    "${extra_args[@]}"
else
  "$PYTHON_BIN" code/publish_baseline_to_hf.py \
    --repo_id "$HF_REPO_ID" \
    --token "$HF_WRITE_TOKEN"
fi
