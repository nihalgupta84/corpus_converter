#!/usr/bin/env bash
set -euo pipefail

CORPUS_DIR=""
BACKEND="pipeline"
METHOD="auto"
DEVICE="auto"
FORCE="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --corpus-dir)
      CORPUS_DIR="$2"
      shift 2
      ;;
    --backend)
      BACKEND="$2"
      shift 2
      ;;
    --method)
      METHOD="$2"
      shift 2
      ;;
    --device)
      DEVICE="$2"
      shift 2
      ;;
    --force)
      FORCE="1"
      shift
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

if [[ -z "$CORPUS_DIR" ]]; then
  echo "Usage:"
  echo "  bash scripts/03_run_mineru_batch.sh --corpus-dir <target_corpus_dir> [--device auto|gpu|cpu] [--force]"
  exit 1
fi

RAW_DIR="$CORPUS_DIR/raw_pdfs"
MINERU_RAW="$CORPUS_DIR/mineru_raw"
LOGS="$CORPUS_DIR/logs"

mkdir -p "$MINERU_RAW" "$LOGS"

if [[ ! -d "$RAW_DIR" ]]; then
  echo "ERROR: raw_pdfs directory not found: $RAW_DIR"
  exit 2
fi

PDF_COUNT=$(find "$RAW_DIR" -type f \( -iname "*.pdf" -o -iname "*.PDF" \) | wc -l)
if [[ "$PDF_COUNT" -eq 0 ]]; then
  echo "ERROR: no PDFs found in $RAW_DIR"
  exit 3
fi

if ! command -v mineru >/dev/null 2>&1; then
  echo "ERROR: mineru command not found. Activate mineru environment first."
  exit 4
fi

if [[ "$FORCE" == "0" ]]; then
  MD_COUNT=$(find "$MINERU_RAW" -name "*.md" 2>/dev/null | wc -l || true)
  if [[ "$MD_COUNT" -ge "$PDF_COUNT" ]]; then
    echo "MinerU raw output already appears complete."
    echo "PDF count: $PDF_COUNT"
    echo "Markdown count: $MD_COUNT"
    echo "Use --force to rerun."
    exit 0
  fi
fi

if [[ "$DEVICE" == "cpu" ]]; then
  export CUDA_VISIBLE_DEVICES=""
  echo "Running in CPU mode. CUDA_VISIBLE_DEVICES is empty."
elif [[ "$DEVICE" == "gpu" ]]; then
  python "$(dirname "$0")/00_check_system.py" --require-gpu
else
  echo "Running in auto device mode."
  python "$(dirname "$0")/00_check_system.py" || true
fi

LOG_FILE="$LOGS/mineru_batch_$(date +%F_%H%M%S).log"

echo "Corpus dir: $CORPUS_DIR"
echo "Raw PDFs: $RAW_DIR"
echo "MinerU raw output: $MINERU_RAW"
echo "PDF count: $PDF_COUNT"
echo "Backend: $BACKEND"
echo "Method: $METHOD"
echo "Device: $DEVICE"
echo "Log: $LOG_FILE"
echo

mineru \
  -p "$RAW_DIR" \
  -o "$MINERU_RAW" \
  -b "$BACKEND" \
  -m "$METHOD" \
  2>&1 | tee "$LOG_FILE"

echo
echo "MinerU complete."
echo "Markdown count:"
find "$MINERU_RAW" -name "*.md" | wc -l
