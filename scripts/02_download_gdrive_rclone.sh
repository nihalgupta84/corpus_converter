#!/usr/bin/env bash
set -euo pipefail

DRIVE_INPUT="${1:-}"
OUT_DIR="${2:-}"
REMOTE="${3:-amity}"

if [[ -z "$DRIVE_INPUT" || -z "$OUT_DIR" ]]; then
  echo "Usage:"
  echo "  bash scripts/02_download_gdrive_rclone.sh <google_drive_folder_link_or_id> <download_output_dir> [rclone_remote]"
  echo
  echo "Example:"
  echo "  bash scripts/02_download_gdrive_rclone.sh 'https://drive.google.com/drive/folders/XXXX' /tmp/downloaded amity"
  exit 1
fi

if ! command -v rclone >/dev/null 2>&1; then
  echo "ERROR: rclone not found. Install rclone and configure Google Drive remote first."
  exit 2
fi

extract_id() {
  local s="$1"

  if [[ "$s" =~ folders/([A-Za-z0-9_-]+) ]]; then
    echo "${BASH_REMATCH[1]}"
    return
  fi

  if [[ "$s" =~ id=([A-Za-z0-9_-]+) ]]; then
    echo "${BASH_REMATCH[1]}"
    return
  fi

  echo "$s"
}

FOLDER_ID="$(extract_id "$DRIVE_INPUT")"

mkdir -p "$OUT_DIR"

echo "Google Drive input: $DRIVE_INPUT"
echo "Folder ID: $FOLDER_ID"
echo "Remote: $REMOTE"
echo "Output: $OUT_DIR"
echo

rclone copy "${REMOTE}:" "$OUT_DIR" \
  --drive-root-folder-id "$FOLDER_ID" \
  --include "*.pdf" \
  --include "*.PDF" \
  --transfers 4 \
  --checkers 8 \
  --drive-chunk-size 64M \
  --retries 10 \
  --low-level-retries 20 \
  -P \
  --log-file "$OUT_DIR/rclone_download.log" \
  --log-level INFO

echo
echo "Download complete."
echo "PDF count:"
find "$OUT_DIR" -type f \( -iname "*.pdf" -o -iname "*.PDF" \) | wc -l
