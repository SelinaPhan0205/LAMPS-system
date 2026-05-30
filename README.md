# LAMPS Reproduction Study

IE105 - UIT - HK2 2025-2026

This repository reproduces and extends the paper:

> Many hands make light work: An LLM-based multi-agent system for detecting malicious PyPI packages
> (Zeshan et al., Journal of Systems and Software, 2026)

The local implementation focuses on the practical malware-detection pipeline around a fine-tuned
CodeBERT classifier, deterministic package scanning, CrewAI-compatible orchestration, D1/D2
evaluation protocols, D2 dataset reconstruction, and a classroom web demo.

## What Is Included

- PyPI package scanner: download a package archive, safely extract Python files, classify each file,
  and aggregate a conservative package-level verdict.
- CodeBERT classifier wrapper: `llms/codebert_llm.py` adapts a Hugging Face sequence classifier to
  the LAMPS/CrewAI interface.
- Deterministic default pipeline: `crew.py` can run without relying on LLM reasoning for the final
  security decision.
- Optional CrewAI path: `crew.py --use_crewai` builds the sequential Fetcher, Extractor,
  Classifier, and Verdict agents.
- D1 evaluation: `evaluation/run_d1_protocol.py` streams the original D1 CSV through `git cat-file`
  to avoid writing raw malicious samples to disk.
- D2 reconstruction: `scripts/` rebuilds a content-labeled D2-like dataset from public DataDog PyPI
  malware samples and local benign files.
- D2 and G3 evaluation: `evaluation/run_d2_protocol.py` and `evaluation/run_d2_imbalanced.py`
  evaluate balanced and real-world class-imbalance settings.
- Web demo: `demo/` exposes a static-analysis demo with FastAPI and a browser UI.
- Tests: `tests/` covers schema validation, extractor policy, runtime settings, payload inspection,
  demo backend behavior, and conservative aggregation.

## Repository Layout

```text
crew.py                         Main package-scanning entrypoint
infer_from_hf.py                Standalone Hugging Face inference CLI
requirements.txt                Core runtime dependencies

llms/
  codebert_llm.py               CodeBERT classifier as a CrewAI-compatible LLM

runtime/
  settings.py                   Environment-based configuration

schemas/
  output_schemas.py             Pydantic contracts for fetch/extract/classify/verdict output

tools/
  pypi_downloader.py            Safe `pip download --no-deps` wrapper with provenance
  archive_extractor.py          Safe archive extraction and D1/D2 file-selection policy
  python_file_reader.py         Guarded source reader for selected `.py` files

scripts/
  build_d1_hashes.py            Build D1 content hashes for D2 deduplication
  extract_datadog.py            Extract public DataDog PyPI malware samples
  codebert_label.py             Content-based labeling with CodeBERT
  build_d2_final.py             Assemble final reconstructed D2 dataset
  supplement_malregistry.py     Optional supplementary malicious-source recovery

evaluation/
  metrics.py                    Classification metrics and imbalance helpers
  run_d1_protocol.py            D1 evaluation protocol
  run_d2_protocol.py            D2 evaluation protocol with head/head_tail/sliding strategies
  run_d2_imbalanced.py          G3 real-world imbalance evaluation

demo/
  backend/                      FastAPI scanner API
  frontend/                     Browser UI for the classroom demo
  README.md                     Demo-specific runbook and speaking script

outputs/
  bao_cao_final_LAMPS.md        Final Vietnamese report
  bao_cao_reproduce_LAMPS.md    Reproduction report
  d2_comparison_report*.md      D2 reconstruction/evaluation notes
  G3_report.md                  Real-world imbalance analysis
  research_gap_analysis.md      Paper gap analysis

tests/                          Unit and smoke tests
```

Generated datasets and malware-containing files are intentionally ignored by Git. Rebuild them with
the scripts below instead of committing them.

## Current Reproduction Results

The most complete local report is `outputs/bao_cao_final_LAMPS.md`.

| Experiment | Local result | Paper claim | Notes |
| --- | ---: | ---: | --- |
| D1 setup.py classification | 96.67% accuracy | 97.7% accuracy | 5,652 loadable samples after safe Git streaming |
| D2 package-level, head strategy | 98.09% accuracy | 99.5% accuracy | 100% recall, 12 false-positive packages |
| D2 package-level, head+tail | 97.93% accuracy | 99.5% accuracy | Better precision, but 4 new false negatives |
| G3 imbalance at 1:50 | 29.6% precision | Not reported | Shows deployment precision collapse under realistic priors |

Important caveat: the original paper's multi-file D2 dataset is not publicly released in a directly
reusable form. The D2 workflow in this repository is a reconstruction based on public DataDog PyPI
malware samples plus the local benign set. It is suitable for reproduction analysis, but it is not a
bit-for-bit copy of the paper's private D2 benchmark.

## Setup

Use Python 3.10+.

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

Set the model and reasoning credentials. The deterministic scanner does not need LLM reasoning for
the verdict, but `runtime/settings.py` still validates that a reasoning credential is configured.

```powershell
$env:CODEBERT_MODEL_ID = "KevinPhamH/codebert-finetuned"
$env:CODEBERT_DEVICE = "auto"

# Choose one provider profile.
$env:LAMPS_REASONING_PROVIDER_PROFILE = "openai"
$env:OPENAI_API_KEY = "<your-openai-key>"

# Or OpenRouter:
# $env:LAMPS_REASONING_PROVIDER_PROFILE = "openrouter"
# $env:OPENROUTER_API_KEY = "<your-openrouter-key>"
# $env:LAMPS_REASONING_BASE_URL = "https://openrouter.ai/api/v1"
```

Optional runtime variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `CODEBERT_MODEL_ID` | required | Hugging Face classifier repo id |
| `CODEBERT_DEVICE` | `auto` | `auto`, `cpu`, `cuda`, or `mps` |
| `HF_TOKEN` | empty | Hugging Face token for private/gated models |
| `LAMPS_OUTPUT_DIR` | `outputs` | Output directory for scanner results |
| `LAMPS_DOWNLOAD_DIR` | `artifacts/pypi_downloads` | Download cache for PyPI archives |
| `LAMPS_EXTRACT_DIR` | `artifacts/extracted` | Extraction workspace |
| `LAMPS_EXTRACT_MODE` | `D2` | File selection mode, `D1` or `D2` |
| `LAMPS_EMPTY_SELECTION_POLICY` | `MALICIOUS` | Verdict when no files are selected |
| `LAMPS_CLASSIFICATION_RETRIES` | `1` | Retry count for classifier failures |
| `LAMPS_ENABLE_REASONING_JUSTIFICATION` | `false` | Use reasoning LLM only for final text justification |

## Run The Package Scanner

Deterministic path, recommended for reproducible local runs:

```powershell
python crew.py `
  --package_spec requests==2.31.0 `
  --output outputs/lamps_verdict_requests.json
```

Equivalent name/version form:

```powershell
python crew.py `
  --package_name requests `
  --package_version 2.31.0
```

CrewAI orchestration path:

```powershell
python crew.py `
  --package_spec requests==2.31.0 `
  --use_crewai `
  --output outputs/lamps_verdict_crewai.json
```

Output shape:

- `fetch`: resolved package name, version, archive path, PyPI URL, SHA256, run id.
- `extraction`: selected Python files and excluded files with reasons.
- `classification`: file-level MALICIOUS/BENIGN predictions and probabilities.
- `final`: package-level conservative verdict. One malicious file marks the package malicious.

## Standalone Hugging Face Inference

Use `infer_from_hf.py` when you only need raw CodeBERT predictions on text or JSONL input:

```powershell
python infer_from_hf.py `
  --model_id KevinPhamH/codebert-finetuned `
  --text "import os; print('hello')" `
  --threshold 0.5
```

For JSONL:

```powershell
python infer_from_hf.py `
  --model_id KevinPhamH/codebert-finetuned `
  --input_jsonl data/input.jsonl `
  --field_name func `
  --output_jsonl outputs/predictions.jsonl
```

## Reproduce D1

The D1 protocol expects the original `lamps-jss` repository to exist locally as `tmp_lamps_jss`.
The script reads the dataset through a Git blob instead of materializing raw malware CSV content.

```powershell
python -m evaluation.run_d1_protocol `
  --model_id KevinPhamH/codebert-finetuned `
  --repo_path tmp_lamps_jss `
  --output outputs/d1_metrics.json `
  --batch_size 64
```

The D1 loader targets Git blob `f8e282b33eb1f8b55dbac68df39340eab3d4e8cd`, matching the local
reproduction workflow documented in `outputs/bao_cao_final_LAMPS.md`.

## Reconstruct D2

The original D2 benchmark is not fully public, so this repository reconstructs a D2-like benchmark.
The generated `D2_dataset/` directory is ignored because it can contain malicious source code.

1. Clone the DataDog malware dataset with sparse checkout:

```powershell
git clone --depth 1 --filter=blob:none --sparse `
  https://github.com/DataDog/malicious-software-packages-dataset.git

cd malicious-software-packages-dataset
git sparse-checkout set samples/pypi
git checkout
cd ..
```

2. Build D1 hashes for deduplication:

```powershell
python scripts/build_d1_hashes.py
```

3. Extract public DataDog PyPI malicious samples:

```powershell
python scripts/extract_datadog.py --max-packages 300
```

4. Label extracted files with CodeBERT confidence thresholds:

```powershell
python scripts/codebert_label.py `
  --model-id KevinPhamH/codebert-finetuned `
  --batch-size 32
```

5. Manually review any `label_int = -1` records in `scripts/labeled_metadata.json`.

6. Assemble the final D2 dataset:

```powershell
python scripts/build_d2_final.py
```

## Evaluate D2

Head-only strategy, matching the baseline CodeBERT truncation behavior:

```powershell
python -m evaluation.run_d2_protocol `
  --model_id KevinPhamH/codebert-finetuned `
  --threshold 0.9 `
  --strategy head `
  --output outputs/d2_baseline_head.json
```

Head+tail strategy:

```powershell
python -m evaluation.run_d2_protocol `
  --model_id KevinPhamH/codebert-finetuned `
  --threshold 0.9 `
  --strategy head_tail `
  --output outputs/d2_head_tail.json
```

Sliding-window strategy:

```powershell
python -m evaluation.run_d2_protocol `
  --model_id KevinPhamH/codebert-finetuned `
  --threshold 0.9 `
  --strategy sliding_window `
  --output outputs/d2_sliding_window.json
```

## Evaluate Real-World Imbalance (G3)

The G3 experiment keeps the benign package pool fixed, samples malicious packages at multiple
ratios, and estimates expected precision under realistic priors.

```powershell
python -m evaluation.run_d2_imbalanced `
  --model_id KevinPhamH/codebert-finetuned `
  --threshold 0.5 `
  --output outputs/g3_imbalance_results.json
```

Summary report: `outputs/G3_report.md`.

## Run The Web Demo

Install demo-only dependencies:

```powershell
python -m pip install -r demo/requirements.txt
```

Start the server:

```powershell
python -m uvicorn demo.backend.app:app --host 127.0.0.1 --port 8000
```

Open:

```text
http://127.0.0.1:8000
```

The demo is quarantined static analysis. It reads local fixtures, tokenizes source code, runs
CodeBERT, and extracts payload indicators as text. It does not install packages, import suspect
code, execute `setup.py`, open URLs, or run shell payloads.

See `demo/README.md` for the full classroom script.

## Run Tests

```powershell
python -m unittest discover tests
```

The tests do not require the full D1/D2 datasets.

## Key Design Decisions

- Conservative aggregation: if any selected file is malicious, the package verdict is malicious.
- Safe archive extraction: ZIP/TAR paths are checked before extraction to prevent path traversal.
- D1 mode selects only `setup.py`; D2 mode excludes tests, docs, examples, CI, config-heavy files,
  and common test naming patterns.
- Classifier coverage is validated. Missing classifier output is treated as malicious by safety
  fallback.
- Package-download provenance includes SHA256, run id, retrieval timestamp, and resolved spec.
- D2 reconstruction uses content-based labeling instead of assigning every file in a malicious
  package to `label=1`.
- Reports explicitly separate reproduction results from paper-private artifacts that cannot be
  verified locally.

## Main Reports

- `outputs/bao_cao_final_LAMPS.md`: final Vietnamese report with D1, D2, truncation, and performance
  analysis.
- `outputs/bao_cao_reproduce_LAMPS.md`: reproduction narrative and result summary.
- `outputs/d2_comparison_report.md`: initial D2 failure analysis.
- `outputs/d2_comparison_report_v2.md`: content-based D2 reconstruction report.
- `outputs/G3_report.md`: real-world class-imbalance evaluation.
- `outputs/research_gap_analysis.md`: paper gap analysis and follow-up research directions.

## Security Notes

This project handles malicious Python source code for research. Keep generated datasets in ignored
local directories, avoid opening samples in tools that auto-execute code, and do not disable host
malware protection just to load raw files. The D1 workflow intentionally streams raw CSV content from
Git objects to avoid writing dangerous intermediate files to disk.

## Citation

If referencing the original method, cite the LAMPS paper:

```text
Zeshan et al. Many hands make light work: An LLM-based multi-agent system for detecting malicious
PyPI packages. Journal of Systems and Software, 2026.
```
