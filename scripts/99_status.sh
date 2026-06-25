#!/usr/bin/env bash
set -euo pipefail

CORPUS_DIR="${1:-}"

if [[ -z "$CORPUS_DIR" ]]; then
  echo "Usage:"
  echo "  bash scripts/99_status.sh <target_corpus_dir>"
  exit 1
fi

if [[ ! -d "$CORPUS_DIR" ]]; then
  echo "ERROR: corpus directory not found: $CORPUS_DIR"
  exit 2
fi

echo "============================================================"
echo "Corpus status"
echo "============================================================"
echo "Corpus dir: $CORPUS_DIR"
echo

echo "Raw PDFs:"
find "$CORPUS_DIR/raw_pdfs" -type f \( -iname "*.pdf" -o -iname "*.PDF" \) 2>/dev/null | wc -l

echo "Downloaded PDFs:"
find "$CORPUS_DIR/downloaded" -type f \( -iname "*.pdf" -o -iname "*.PDF" \) 2>/dev/null | wc -l

echo "MinerU raw paper folders:"
find "$CORPUS_DIR/mineru_raw" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l

echo "MinerU raw markdown:"
find "$CORPUS_DIR/mineru_raw" -name "*.md" 2>/dev/null | wc -l

echo "Final done files:"
find "$CORPUS_DIR/extracted" -name ".done" 2>/dev/null | wc -l

echo "Final markdown:"
find "$CORPUS_DIR/extracted" -name "*.md" 2>/dev/null | wc -l

echo "Final meta:"
find "$CORPUS_DIR/extracted" -name "*_meta.json" 2>/dev/null | wc -l

echo "Final images/tables:"
find "$CORPUS_DIR/extracted" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | wc -l

echo
echo "Recent logs:"
find "$CORPUS_DIR/logs" -maxdepth 1 -type f 2>/dev/null | sort | tail -10 || true

echo "============================================================"
