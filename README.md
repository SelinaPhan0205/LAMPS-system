# LAMPS - Tái Hiện Hệ Thống Phát Hiện Package PyPI Độc Hại

IE105 - UIT - HK2 2025-2026

Repo này tái hiện và mở rộng bài báo:

> Many hands make light work: An LLM-based multi-agent system for detecting malicious PyPI packages
> (Zeshan et al., Journal of Systems and Software, 2026)

Mục tiêu của repo là dựng lại pipeline phát hiện package PyPI độc hại bằng CodeBERT fine-tuned,
kèm phần điều phối kiểu LAMPS/CrewAI, đánh giá lại trên D1/D2, tái thiết dataset D2, phân tích
class imbalance thực tế, và demo web phục vụ trình bày trên lớp.

## Repo Này Có Gì?

- Scanner package PyPI: tải archive bằng `pip download --no-deps`, giải nén an toàn, chọn file
  Python cần phân tích, phân loại từng file, rồi gom verdict ở cấp package.
- Wrapper CodeBERT: `llms/codebert_llm.py` biến model Hugging Face sequence classifier thành LLM
  tương thích với CrewAI.
- Pipeline deterministic: `crew.py` chạy được theo đường ổn định, không phụ thuộc LLM reasoning để
  ra quyết định bảo mật cuối cùng.
- Pipeline CrewAI tùy chọn: `crew.py --use_crewai` dựng chuỗi agent Fetcher, Extractor, Classifier
  và Verdict.
- Đánh giá D1: `evaluation/run_d1_protocol.py` đọc CSV gốc qua `git cat-file` để tránh ghi raw
  malware ra đĩa.
- Tái thiết D2: các script trong `scripts/` dựng lại dataset kiểu D2 từ DataDog PyPI malware samples
  và tập benign local.
- Đánh giá D2/G3: `evaluation/run_d2_protocol.py` và `evaluation/run_d2_imbalanced.py` chạy benchmark
  D2 và kiểm tra class imbalance gần thực tế hơn.
- Demo web: `demo/` có FastAPI backend và giao diện browser để minh họa pipeline static analysis.
- Test suite: `tests/` kiểm tra schema, policy giải nén, runtime settings, payload inspector, demo
  backend và conservative aggregation.

## Cấu Trúc Thư Mục

```text
crew.py                         Entrypoint chính để scan package PyPI
infer_from_hf.py                CLI inference Hugging Face độc lập
requirements.txt                Dependency chính của repo

llms/
  codebert_llm.py               Wrapper CodeBERT tương thích CrewAI

runtime/
  settings.py                   Cấu hình từ environment variables

schemas/
  output_schemas.py             Pydantic schema cho fetch/extract/classify/verdict

tools/
  pypi_downloader.py            Wrapper `pip download --no-deps` có provenance
  archive_extractor.py          Giải nén an toàn và policy chọn file D1/D2
  python_file_reader.py         Đọc source `.py` có kiểm soát

scripts/
  build_d1_hashes.py            Tạo hash D1 để dedup khi dựng D2
  extract_datadog.py            Trích xuất sample PyPI malware từ DataDog
  codebert_label.py             Gán nhãn content-based bằng CodeBERT
  build_d2_final.py             Lắp dataset D2 tái thiết cuối cùng
  supplement_malregistry.py     Bổ sung nguồn malicious nếu cần

evaluation/
  metrics.py                    Metric classification và helper imbalance
  run_d1_protocol.py            Protocol đánh giá D1
  run_d2_protocol.py            Protocol đánh giá D2 với head/head_tail/sliding
  run_d2_imbalanced.py          G3: đánh giá class imbalance thực tế
  MP_Hunter.ipynb               Notebook baseline/so sánh MP-Hunter

TF-IDF/
  cfg88_01_final.ipynb          Notebook baseline TF-IDF

codebert_finetuned/
  code/                         Code train/evaluate/infer CodeBERT baseline
  data/                         JSONL train/val/test dùng cho fine-tuning
  evaluator/                    Evaluator phụ trợ
  logs/                         Log chạy baseline

demo/
  backend/                      FastAPI scanner API
  frontend/                     Giao diện browser cho demo trên lớp
  README.md                     Runbook và kịch bản nói demo

outputs/
  bao_cao_final_LAMPS.md        Báo cáo cuối tiếng Việt
  bao_cao_reproduce_LAMPS.md    Báo cáo tái hiện
  d2_comparison_report*.md      Báo cáo phân tích/tái thiết D2
  G3_report.md                  Báo cáo real-world imbalance
  research_gap_analysis.md      Phân tích gap của paper

tests/                          Unit tests và smoke tests
```

Các dataset sinh ra trong quá trình chạy, thư mục chứa raw malware, và artifact trung gian được
ignore bằng `.gitignore`. Khi cần thì dựng lại bằng script, không commit trực tiếp raw dataset độc hại.

## Kết Quả Tái Hiện Hiện Tại

Báo cáo đầy đủ nhất nằm ở `outputs/bao_cao_final_LAMPS.md`.

| Thực nghiệm | Kết quả local | Paper công bố | Ghi chú |
| --- | ---: | ---: | --- |
| D1 - phân loại `setup.py` | 96.67% accuracy | 97.7% accuracy | 5,652 sample đọc được bằng Git streaming |
| D2 package-level, strategy `head` | 98.09% accuracy | 99.5% accuracy | Recall 100%, có 12 false-positive package |
| D2 package-level, strategy `head_tail` | 97.93% accuracy | 99.5% accuracy | Precision tốt hơn nhưng xuất hiện 4 false negative |
| G3 imbalance tỷ lệ 1:50 | 29.6% precision | Không báo cáo | Cho thấy precision giảm mạnh khi gần bối cảnh thực tế |

Lưu ý quan trọng: dataset D2 multi-file gốc của paper không được public đầy đủ dưới dạng có thể dùng
trực tiếp. D2 trong repo này là bản tái thiết từ DataDog PyPI malware samples công khai kết hợp tập
benign local. Vì vậy đây là reproduction-oriented benchmark, không phải bản sao bit-for-bit của D2
riêng trong paper.

## Cài Đặt

Yêu cầu Python 3.10+.

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

Thiết lập model và credential reasoning. Pipeline deterministic không cần LLM reasoning để quyết định
verdict, nhưng `runtime/settings.py` vẫn yêu cầu có credential reasoning hợp lệ.

```powershell
$env:CODEBERT_MODEL_ID = "KevinPhamH/codebert-finetuned"
$env:CODEBERT_DEVICE = "auto"

# Chọn profile OpenAI.
$env:LAMPS_REASONING_PROVIDER_PROFILE = "openai"
$env:OPENAI_API_KEY = "<your-openai-key>"

# Hoặc dùng OpenRouter:
# $env:LAMPS_REASONING_PROVIDER_PROFILE = "openrouter"
# $env:OPENROUTER_API_KEY = "<your-openrouter-key>"
# $env:LAMPS_REASONING_BASE_URL = "https://openrouter.ai/api/v1"
```

Các biến môi trường tùy chọn:

| Biến | Mặc định | Ý nghĩa |
| --- | --- | --- |
| `CODEBERT_MODEL_ID` | bắt buộc | Repo id của classifier trên Hugging Face |
| `CODEBERT_DEVICE` | `auto` | `auto`, `cpu`, `cuda`, hoặc `mps` |
| `HF_TOKEN` | rỗng | Token Hugging Face nếu model private/gated |
| `LAMPS_OUTPUT_DIR` | `outputs` | Nơi lưu kết quả scanner |
| `LAMPS_DOWNLOAD_DIR` | `artifacts/pypi_downloads` | Cache archive tải từ PyPI |
| `LAMPS_EXTRACT_DIR` | `artifacts/extracted` | Workspace giải nén |
| `LAMPS_EXTRACT_MODE` | `D2` | Chế độ chọn file, `D1` hoặc `D2` |
| `LAMPS_EMPTY_SELECTION_POLICY` | `MALICIOUS` | Verdict khi extractor không chọn được file nào |
| `LAMPS_CLASSIFICATION_RETRIES` | `1` | Số lần retry khi classifier lỗi |
| `LAMPS_ENABLE_REASONING_JUSTIFICATION` | `false` | Bật LLM reasoning chỉ để viết justification cuối |

## Chạy Scanner Package PyPI

Đường deterministic, nên dùng cho chạy local/tái hiện:

```powershell
python crew.py `
  --package_spec requests==2.31.0 `
  --output outputs/lamps_verdict_requests.json
```

Có thể truyền name/version riêng:

```powershell
python crew.py `
  --package_name requests `
  --package_version 2.31.0
```

Đường CrewAI orchestration:

```powershell
python crew.py `
  --package_spec requests==2.31.0 `
  --use_crewai `
  --output outputs/lamps_verdict_crewai.json
```

Output gồm:

- `fetch`: tên package, version, archive path, URL PyPI, SHA256, run id.
- `extraction`: danh sách file Python được chọn và file bị loại kèm lý do.
- `classification`: prediction MALICIOUS/BENIGN và probability cho từng file.
- `final`: verdict cấp package theo chính sách conservative. Chỉ cần một file malicious thì package
  bị đánh dấu malicious.

## Chạy Inference Hugging Face Độc Lập

Dùng `infer_from_hf.py` khi chỉ cần prediction thô từ CodeBERT trên text hoặc JSONL:

```powershell
python infer_from_hf.py `
  --model_id KevinPhamH/codebert-finetuned `
  --text "import os; print('hello')" `
  --threshold 0.5
```

Với JSONL:

```powershell
python infer_from_hf.py `
  --model_id KevinPhamH/codebert-finetuned `
  --input_jsonl data/input.jsonl `
  --field_name func `
  --output_jsonl outputs/predictions.jsonl
```

## Tái Hiện D1

Protocol D1 cần repo gốc `lamps-jss` tồn tại local ở thư mục `tmp_lamps_jss`. Script đọc dataset
qua Git blob thay vì ghi raw malware CSV ra filesystem.

```powershell
python -m evaluation.run_d1_protocol `
  --model_id KevinPhamH/codebert-finetuned `
  --repo_path tmp_lamps_jss `
  --output outputs/d1_metrics.json `
  --batch_size 64
```

Loader D1 dùng Git blob `f8e282b33eb1f8b55dbac68df39340eab3d4e8cd`, khớp workflow đã mô tả trong
`outputs/bao_cao_final_LAMPS.md`.

## Tái Thiết D2

Vì D2 gốc không public đầy đủ, repo này dựng lại một benchmark kiểu D2. Thư mục sinh ra
`D2_dataset/` bị ignore vì có thể chứa source code độc hại.

1. Clone DataDog malware dataset bằng sparse checkout:

```powershell
git clone --depth 1 --filter=blob:none --sparse `
  https://github.com/DataDog/malicious-software-packages-dataset.git

cd malicious-software-packages-dataset
git sparse-checkout set samples/pypi
git checkout
cd ..
```

2. Tạo hash D1 để dedup:

```powershell
python scripts/build_d1_hashes.py
```

3. Trích xuất sample PyPI malicious từ DataDog:

```powershell
python scripts/extract_datadog.py --max-packages 300
```

4. Gán nhãn file bằng CodeBERT:

```powershell
python scripts/codebert_label.py `
  --model-id KevinPhamH/codebert-finetuned `
  --batch-size 32
```

5. Review thủ công các record có `label_int = -1` trong `scripts/labeled_metadata.json`.

6. Lắp dataset D2 cuối:

```powershell
python scripts/build_d2_final.py
```

## Đánh Giá D2

Strategy `head`, tương ứng hành vi truncation baseline của CodeBERT:

```powershell
python -m evaluation.run_d2_protocol `
  --model_id KevinPhamH/codebert-finetuned `
  --threshold 0.9 `
  --strategy head `
  --output outputs/d2_baseline_head.json
```

Strategy `head_tail`:

```powershell
python -m evaluation.run_d2_protocol `
  --model_id KevinPhamH/codebert-finetuned `
  --threshold 0.9 `
  --strategy head_tail `
  --output outputs/d2_head_tail.json
```

Strategy `sliding_window`:

```powershell
python -m evaluation.run_d2_protocol `
  --model_id KevinPhamH/codebert-finetuned `
  --threshold 0.9 `
  --strategy sliding_window `
  --output outputs/d2_sliding_window.json
```

## Đánh Giá Class Imbalance Thực Tế (G3)

Thực nghiệm G3 giữ nguyên benign pool, sample malicious packages theo nhiều tỷ lệ, rồi ước tính
precision khi prior gần thực tế hơn.

```powershell
python -m evaluation.run_d2_imbalanced `
  --model_id KevinPhamH/codebert-finetuned `
  --threshold 0.5 `
  --output outputs/g3_imbalance_results.json
```

Báo cáo tóm tắt: `outputs/G3_report.md`.

## Chạy Web Demo

Cài dependency riêng cho demo:

```powershell
python -m pip install -r demo/requirements.txt
```

Khởi động server:

```powershell
python -m uvicorn demo.backend.app:app --host 127.0.0.1 --port 8000
```

Mở trình duyệt:

```text
http://127.0.0.1:8000
```

Demo là quarantined static analysis. Backend chỉ đọc fixture local, tokenize source, chạy CodeBERT
và trích IOC/payload dưới dạng text. Demo không install package, không import code nghi ngờ, không
chạy `setup.py`, không mở URL và không execute shell payload.

Kịch bản nói demo đầy đủ nằm ở `demo/README.md`.

## Chạy Tests

```powershell
python -m unittest discover tests
```

Các test này không cần full D1/D2 dataset.

## Quyết Định Thiết Kế Chính

- Conservative aggregation: chỉ cần một file selected bị phân loại malicious thì cả package là
  malicious.
- Giải nén an toàn: kiểm tra path trong ZIP/TAR trước khi extract để tránh path traversal.
- Chế độ D1 chỉ lấy `setup.py`; chế độ D2 loại tests, docs, examples, CI, config-heavy files và
  pattern file test phổ biến.
- Kiểm tra coverage classifier. Nếu thiếu output cho file đã selected, hệ thống fallback sang
  malicious theo hướng an toàn.
- Provenance khi tải package gồm SHA256, run id, timestamp và resolved spec.
- D2 reconstruction dùng content-based labeling, không gán `label=1` cho toàn bộ file trong package
  malicious.
- Báo cáo tách rõ phần reproduce được tại local và phần artifact riêng của paper không thể kiểm chứng
  trực tiếp.

## Báo Cáo Chính

- `outputs/bao_cao_final_LAMPS.md`: báo cáo cuối tiếng Việt, gồm D1, D2, truncation và hiệu năng.
- `outputs/bao_cao_reproduce_LAMPS.md`: báo cáo tái hiện và tổng hợp kết quả.
- `outputs/d2_comparison_report.md`: phân tích lỗi D2 ban đầu.
- `outputs/d2_comparison_report_v2.md`: báo cáo tái thiết D2 bằng content-based labeling.
- `outputs/G3_report.md`: đánh giá class imbalance thực tế.
- `outputs/research_gap_analysis.md`: phân tích gap của paper và hướng nghiên cứu tiếp theo.

## Lưu Ý An Toàn

Repo này xử lý source code Python độc hại phục vụ nghiên cứu. Không chạy trực tiếp sample, không
import package nghi ngờ, không disable malware protection chỉ để đọc raw file. Các dataset sinh ra
nên nằm trong thư mục ignored local. Workflow D1 cố ý stream raw CSV từ Git object để hạn chế việc
ghi file độc hại trung gian ra đĩa.

## Citation

Nếu trích dẫn phương pháp gốc, dùng paper LAMPS:

```text
Zeshan et al. Many hands make light work: An LLM-based multi-agent system for detecting malicious
PyPI packages. Journal of Systems and Software, 2026.
```
