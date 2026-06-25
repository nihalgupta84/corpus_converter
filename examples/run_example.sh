#!/usr/bin/env bash
set -euo pipefail

cd /workspace/projects/language/corpus_converter

source /workspace/miniconda3/etc/profile.d/conda.sh
conda activate mineru

bash scripts/05_run_all.sh \
  --input "https://drive.google.com/drive/folders/YOUR_FOLDER_ID?usp=sharing" \
  --corpus-dir /workspace/projects/vision/aqi_prediction/corpus \
  --remote amity \
  --device gpu \
  --rename-mode title
