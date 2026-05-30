#!/usr/bin/env python3
import argparse
import json
import os
import shutil
from pathlib import Path
from typing import Dict

def _dependency_error(package_name: str) -> SystemExit:
    return SystemExit(
        f"Missing dependency '{package_name}'. "
        "Run this script with your project environment Python, for example: "
        "'/opt/homebrew/Caskroom/miniconda/base/envs/imrenv/bin/python code/publish_baseline_to_hf.py ...' "
        "or use 'bash code/upload_baseline_to_hf.sh'."
    )


try:
    import torch
except ModuleNotFoundError as exc:
    raise _dependency_error("torch") from exc

try:
    from huggingface_hub import HfApi
except ModuleNotFoundError as exc:
    raise _dependency_error("huggingface_hub") from exc

try:
    from transformers import AutoConfig, AutoModelForSequenceClassification, AutoTokenizer
except ModuleNotFoundError as exc:
    raise _dependency_error("transformers") from exc

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def _normalize_state_dict(raw_state_dict: Dict[str, torch.Tensor]) -> Dict[str, torch.Tensor]:
    """Convert project-specific checkpoint keys to Hugging Face model keys."""
    normalized = {}
    for key, value in raw_state_dict.items():
        new_key = key
        if new_key.startswith("module."):
            new_key = new_key[len("module.") :]
        if new_key.startswith("encoder."):
            new_key = new_key[len("encoder.") :]

        # Dropout layer has no trainable weights; keep only encoder/classifier params.
        if new_key.startswith("dropout."):
            continue

        normalized[new_key] = value
    return normalized


def _write_model_card(export_dir: Path, repo_id: str) -> None:
    readme = f"""---
language:
- en
library_name: transformers
pipeline_tag: text-classification
---

# {repo_id}

This model is converted from the local baseline checkpoint in this project:
- source checkpoint: saved_models/codebert-finetuned/checkpoint-best-acc/model.bin
- architecture: CodeBERT (RobertaForSequenceClassification)
- task: vulnerability detection on source code snippets

## Inference Notes

The model was trained with a single-logit binary objective.
Use sigmoid(logit) to get vulnerability probability and threshold at 0.5 by default.
"""
    (export_dir / "README.md").write_text(readme, encoding="utf-8")


def export_baseline_checkpoint(
    checkpoint_path: Path,
    export_dir: Path,
    base_model_name: str,
    tokenizer_name: str,
) -> None:
    export_dir.mkdir(parents=True, exist_ok=True)

    if not checkpoint_path.exists():
        raise FileNotFoundError(f"Checkpoint not found: {checkpoint_path}")

    print(f"Loading baseline checkpoint from: {checkpoint_path}")
    raw = torch.load(checkpoint_path, map_location="cpu")
    if not isinstance(raw, dict):
        raise RuntimeError("Checkpoint format is invalid. Expected a state_dict dictionary.")

    normalized = _normalize_state_dict(raw)
    if not any(key.startswith("roberta.") for key in normalized):
        raise RuntimeError(
            "Converted state_dict does not look like CodeBERT/Roberta weights. "
            "Expected keys to start with 'roberta.'."
        )

    config = AutoConfig.from_pretrained(base_model_name)
    config.num_labels = 1
    config.id2label = {"0": "VULNERABILITY_SCORE"}
    config.label2id = {"VULNERABILITY_SCORE": 0}

    model = AutoModelForSequenceClassification.from_pretrained(base_model_name, config=config)
    load_result = model.load_state_dict(normalized, strict=False)

    if load_result.unexpected_keys:
        raise RuntimeError(
            "Unexpected keys while loading checkpoint: "
            + ", ".join(load_result.unexpected_keys)
        )
    if load_result.missing_keys:
        print("Warning: missing keys while loading checkpoint:")
        for key in load_result.missing_keys:
            print(f"  - {key}")

    tokenizer = AutoTokenizer.from_pretrained(tokenizer_name)

    model.save_pretrained(export_dir)
    tokenizer.save_pretrained(export_dir)

    inference_cfg = {
        "max_length": 400,
        "decision_threshold": 0.5,
        "sigmoid_output": True,
        "notes": "probability = sigmoid(logit)"
    }
    (export_dir / "inference_config.json").write_text(
        json.dumps(inference_cfg, indent=2),
        encoding="utf-8",
    )

    # Attach evaluation summary if available.
    eval_json = checkpoint_path.parents[1] / "evaluation.json"
    if eval_json.exists():
        shutil.copy2(eval_json, export_dir / "evaluation.json")

    print(f"HF-ready model files exported to: {export_dir}")


def upload_to_hub(export_dir: Path, repo_id: str, token: str, private: bool, commit_message: str) -> None:
    api = HfApi()
    api.create_repo(repo_id=repo_id, token=token, private=private, repo_type="model", exist_ok=True)

    print(f"Uploading {export_dir} to https://huggingface.co/{repo_id} ...")
    api.upload_folder(
        repo_id=repo_id,
        repo_type="model",
        folder_path=str(export_dir),
        token=token,
        commit_message=commit_message,
    )
    print(f"Upload completed: https://huggingface.co/{repo_id}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Export and upload baseline CodeBERT checkpoint to Hugging Face Hub.")
    parser.add_argument(
        "--checkpoint_path",
        type=Path,
        default=PROJECT_ROOT / "saved_models" / "codebert-finetuned" / "checkpoint-best-acc" / "model.bin",
        help="Path to local baseline checkpoint model.bin",
    )
    parser.add_argument(
        "--export_dir",
        type=Path,
        default=PROJECT_ROOT / "saved_models" / "codebert-finetuned" / "hf_export",
        help="Directory to write Hugging Face-compatible files",
    )
    parser.add_argument(
        "--base_model_name",
        type=str,
        default="microsoft/codebert-base",
        help="Base encoder model used during fine-tuning",
    )
    parser.add_argument(
        "--tokenizer_name",
        type=str,
        default="microsoft/codebert-base",
        help="Tokenizer to save with the exported model",
    )
    parser.add_argument(
        "--repo_id",
        type=str,
        default=os.getenv("HF_REPO_ID", ""),
        help="Target repo id, e.g. username/codebert-vuln-baseline (or set HF_REPO_ID)",
    )
    parser.add_argument(
        "--token",
        type=str,
        default=os.getenv("HF_WRITE_TOKEN", ""),
        help="Hugging Face write token (or set HF_WRITE_TOKEN)",
    )
    parser.add_argument("--private", action="store_true", help="Create or keep repository private")
    parser.add_argument(
        "--commit_message",
        type=str,
        default="Upload baseline CodeBERT vulnerability model",
        help="Commit message for Hub upload",
    )
    parser.add_argument(
        "--skip_upload",
        action="store_true",
        help="Only export local HF files without pushing to Hugging Face Hub",
    )

    args = parser.parse_args()

    export_baseline_checkpoint(
        checkpoint_path=args.checkpoint_path,
        export_dir=args.export_dir,
        base_model_name=args.base_model_name,
        tokenizer_name=args.tokenizer_name,
    )
    _write_model_card(args.export_dir, args.repo_id or "your-username/your-model")

    if args.skip_upload:
        print("skip_upload=True, finished local export only.")
        return

    token = args.token or ""
    if not token:
        raise RuntimeError("Missing write token. Pass --token or set it from your shell variable.")
    if not args.repo_id:
        raise RuntimeError("Missing --repo_id. Example: your-username/codebert-vuln-baseline")

    upload_to_hub(
        export_dir=args.export_dir,
        repo_id=args.repo_id,
        token=token,
        private=args.private,
        commit_message=args.commit_message,
    )


if __name__ == "__main__":
    main()
