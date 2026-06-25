#!/usr/bin/env bash
set -euo pipefail

INPUT=""
CORPUS_DIR=""
REMOTE="amity"
DEVICE="auto"
RENAME_MODE="title"
FORCE="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input)
      INPUT="$2"
      shift 2
      ;;
    --corpus-dir)
      CORPUS_DIR="$2"
      shift 2
      ;;
    --remote)
      REMOTE="$2"
      shift 2
      ;;
    --device)
      DEVICE="$2"
      shift 2
      ;;
    --rename-mode)
      RENAME_MODE="$2"
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

if [[ -z "$INPUT" || -z "$CORPUS_DIR" ]]; then
  echo "Usage:"
  echo "  bash scripts/05_run_all.sh --input <gdrive_link_or_local_path> --corpus-dir <target_corpus_dir> [--remote amity] [--device auto|gpu|cpu] [--rename-mode title|keep] [--force]"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$CORPUS_DIR"/{downloaded,raw_pdfs,mineru_raw,extracted,logs,manifests}

echo "============================================================"
echo "Corpus Converter"
echo "============================================================"
echo "Input: $INPUT"
echo "Corpus dir: $CORPUS_DIR"
echo "Remote: $REMOTE"
echo "Device: $DEVICE"
echo "Rename mode: $RENAME_MODE"
echo "Force: $FORCE"
echo "============================================================"

python "$SCRIPT_DIR/00_check_system.py" || true

LOCAL_INPUT="$INPUT"

if [[ "$INPUT" == *"drive.google.com"* || "$INPUT" =~ ^[A-Za-z0-9_-]{20,}$ ]]; then
  echo
  echo "[1/4] Google Drive input detected. Downloading PDFs with rclone..."
  bash "$SCRIPT_DIR/02_download_gdrive_rclone.sh" "$INPUT" "$CORPUS_DIR/downloaded" "$REMOTE"
  LOCAL_INPUT="$CORPUS_DIR/downloaded"
else
  echo
  echo "[1/4] Local input detected."
fi

echo
echo "[2/4] Preparing raw PDFs..."
if [[ "$FORCE" == "1" ]]; then
  python "$SCRIPT_DIR/01_prepare_inputs.py" \
    --input "$LOCAL_INPUT" \
    --corpus-dir "$CORPUS_DIR" \
    --rename-mode "$RENAME_MODE" \
    --force
else
  python "$SCRIPT_DIR/01_prepare_inputs.py" \
    --input "$LOCAL_INPUT" \
    --corpus-dir "$CORPUS_DIR" \
    --rename-mode "$RENAME_MODE"
fi

echo
echo "[3/4] Running MinerU batch..."
if [[ "$FORCE" == "1" ]]; then
  bash "$SCRIPT_DIR/03_run_mineru_batch.sh" \
    --corpus-dir "$CORPUS_DIR" \
    --device "$DEVICE" \
    --force
else
  bash "$SCRIPT_DIR/03_run_mineru_batch.sh" \
    --corpus-dir "$CORPUS_DIR" \
    --device "$DEVICE"
fi

echo
echo "[4/4] Formatting MinerU output..."
if [[ "$FORCE" == "1" ]]; then
  python "$SCRIPT_DIR/04_format_mineru_output.py" \
    --mineru-raw "$CORPUS_DIR/mineru_raw" \
    --out-dir "$CORPUS_DIR/extracted" \
    --force
else
  python "$SCRIPT_DIR/04_format_mineru_output.py" \
    --mineru-raw "$CORPUS_DIR/mineru_raw" \
    --out-dir "$CORPUS_DIR/extracted"
fi

echo
echo "============================================================"
echo "DONE"
echo "Final corpus:"
echo "$CORPUS_DIR/extracted"
echo "============================================================"
