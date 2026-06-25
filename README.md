# Corpus Converter

A reusable **MinerU-based corpus conversion pipeline** for research papers.

Corpus Converter takes PDFs from a Google Drive folder, Google Drive folder ID, local folder, or single local PDF, then converts them into a clean Markdown corpus with extracted figures, tables, logs, and manifests.

The pipeline is designed for batch processing: it prepares all PDFs first, runs MinerU once on the full PDF folder, and then formats the raw MinerU output into a clean nested corpus layout.

---

## Features

- Supports Google Drive folder links.
- Supports Google Drive folder IDs.
- Supports local folders containing PDFs.
- Supports a single local PDF file.
- Ignores non-PDF files such as `.html`, `.htm`, `.url`, `.txt`, `.docx`, and similar files.
- Copies files only; no symlinks are created.
- Renames PDFs using detected paper titles when possible.
- Runs MinerU once on the full PDF folder for faster batch extraction.
- Converts MinerU raw output into a clean, reusable Markdown corpus.
- Keeps logs and manifests for status tracking and reproducibility.

---

## Final Output Layout

```text
target_corpus/
├── raw_pdfs/
├── mineru_raw/
├── extracted/
│   └── Paper_Title_Slug/
│       ├── Paper_Title_Slug/
│       │   ├── _page_0_Figure_0.jpg
│       │   ├── _page_1_Table_0.jpg
│       │   ├── Paper_Title_Slug.md
│       │   └── Paper_Title_Slug_meta.json
│       └── .done
├── logs/
└── manifests/
```

The final usable corpus path is:

```text
target_corpus/extracted
```

---

## Project Structure

```text
corpus_converter/
├── README.md
├── .gitignore
├── environment.yml
├── requirements-extra.txt
├── scripts/
│   ├── 00_check_system.py
│   ├── 01_prepare_inputs.py
│   ├── 02_download_gdrive_rclone.sh
│   ├── 03_run_mineru_batch.sh
│   ├── 04_format_mineru_output.py
│   ├── 05_run_all.sh
│   └── 99_status.sh
└── examples/
    └── run_example.sh
```

---

## Requirements

- Linux server, Ubuntu, or WSL environment.
- Conda or Miniconda installed.
- Optional NVIDIA GPU for faster MinerU inference.
- `rclone` is required only when using Google Drive input.
- Python dependencies from:
  - `environment.yml`
  - `requirements-extra.txt`
  - `mineru[all]`

---

## Setup

### 1. Go to the project directory

```bash
cd /workspace/projects/language/corpus_converter
```

### 2. Create the Conda environment

```bash
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main || true
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r || true

conda env create -f environment.yml
conda activate mineru
```

### 3. Install Python packages

```bash
python -m pip install -U pip uv
python -m uv pip install -U "mineru[all]"
python -m pip install -r requirements-extra.txt
```

### 4. Check the system

```bash
python scripts/00_check_system.py
```

If GPU is required, run:

```bash
python scripts/00_check_system.py --require-gpu
```

---

## Optional: Fix PyTorch CUDA Wheel

If `torch.cuda.is_available()` is `False`, install the PyTorch wheel that matches your CUDA driver.

### CUDA 12.8

```bash
python -m pip uninstall -y torch torchvision torchaudio triton xformers
python -m pip freeze | grep -E '^nvidia-.*-cu13' | cut -d= -f1 | xargs -r python -m pip uninstall -y

python -m pip install --no-cache-dir \
  torch torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/cu128
```

### CPU fallback

```bash
python -m pip install --no-cache-dir \
  torch torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/cpu
```

Verify again:

```bash
python scripts/00_check_system.py
```

---

## Google Drive Setup with rclone

Use this section only if your PDFs are stored in Google Drive.

### 1. Install rclone

```bash
curl -fsSL https://rclone.org/install.sh | bash
rclone version
```

### 2. Configure the Google Drive remote

```bash
rclone config
```

Recommended choices:

```text
n
name> amity
Storage> drive
client_id> press Enter
client_secret> press Enter
scope> 2
root_folder_id> press Enter
service_account_file> press Enter
Edit advanced config? n
Use auto config? n
```

On a server without browser access, choose manual authentication. Run the generated `rclone authorize` command on your local machine with browser access, then paste the returned token back into the server.

### 3. Check the remote

```bash
rclone lsd amity:
```

If you use a different remote name, replace `amity` in all commands with your own rclone remote name.

---

## Usage

### Option A: Convert a Google Drive folder

```bash
cd /workspace/projects/language/corpus_converter
conda activate mineru

bash scripts/05_run_all.sh \
  --input "https://drive.google.com/drive/folders/YOUR_FOLDER_ID?usp=sharing" \
  --corpus-dir /workspace/projects/my_project/corpus \
  --remote amity \
  --device gpu \
  --rename-mode title
```

### Option B: Convert a local PDF folder

```bash
cd /workspace/projects/language/corpus_converter
conda activate mineru

bash scripts/05_run_all.sh \
  --input /path/to/local/pdf_folder \
  --corpus-dir /workspace/projects/my_project/corpus \
  --device gpu \
  --rename-mode title
```

### Option C: Convert a single local PDF

```bash
cd /workspace/projects/language/corpus_converter
conda activate mineru

bash scripts/05_run_all.sh \
  --input /path/to/paper.pdf \
  --corpus-dir /workspace/projects/my_project/corpus \
  --device gpu \
  --rename-mode title
```

### Option D: Run in CPU mode

```bash
bash scripts/05_run_all.sh \
  --input /path/to/local/pdf_folder \
  --corpus-dir /workspace/projects/my_project/corpus \
  --device cpu \
  --rename-mode title
```

---

## Step-by-Step Usage

Use these commands when you want to run each stage manually.

### 1. Prepare PDFs

```bash
python scripts/01_prepare_inputs.py \
  --input /path/to/pdf_folder \
  --corpus-dir /workspace/projects/my_project/corpus \
  --rename-mode title
```

This copies valid PDF files into:

```text
/workspace/projects/my_project/corpus/raw_pdfs
```

### 2. Download Google Drive PDFs

```bash
bash scripts/02_download_gdrive_rclone.sh \
  "https://drive.google.com/drive/folders/YOUR_FOLDER_ID?usp=sharing" \
  /workspace/projects/my_project/corpus/downloaded \
  amity
```

### 3. Run MinerU on the full PDF folder

```bash
bash scripts/03_run_mineru_batch.sh \
  --corpus-dir /workspace/projects/my_project/corpus \
  --device gpu
```

MinerU output will be saved to:

```text
/workspace/projects/my_project/corpus/mineru_raw
```

### 4. Format the final corpus

```bash
python scripts/04_format_mineru_output.py \
  --mineru-raw /workspace/projects/my_project/corpus/mineru_raw \
  --out-dir /workspace/projects/my_project/corpus/extracted \
  --force
```

The final clean Markdown corpus will be saved to:

```text
/workspace/projects/my_project/corpus/extracted
```

### 5. Check status

```bash
bash scripts/99_status.sh /workspace/projects/my_project/corpus
```

---

## Run in Background with nohup

Use this when processing many PDFs on a remote server.

```bash
cd /workspace/projects/language/corpus_converter

mkdir -p /workspace/projects/my_project/corpus/logs

nohup bash -lc '
source /workspace/miniconda3/etc/profile.d/conda.sh
conda activate mineru

bash scripts/05_run_all.sh \
  --input "https://drive.google.com/drive/folders/YOUR_FOLDER_ID?usp=sharing" \
  --corpus-dir /workspace/projects/my_project/corpus \
  --remote amity \
  --device gpu \
  --rename-mode title
' > /workspace/projects/my_project/corpus/logs/nohup_corpus_converter_$(date +%F_%H%M).log 2>&1 &

echo $!
```

---

## Monitor Progress

Tail the latest log file:

```bash
tail -f /workspace/projects/my_project/corpus/logs/nohup_corpus_converter_*.log
```

Check corpus status:

```bash
bash scripts/99_status.sh /workspace/projects/my_project/corpus
```

Check running processes:

```bash
ps -ef | grep -E 'mineru|05_run_all|03_run_mineru' | grep -v grep
```

---

## Notes

MinerU should run on the full folder, not one PDF at a time.

Slow method:

```text
load MinerU models -> process 1 PDF -> shutdown -> repeat
```

Fast method:

```text
load MinerU models once -> process entire raw_pdfs folder -> shutdown
```

This project uses the fast method.

---

## Troubleshooting

### `torch.cuda.is_available()` is `False`

Install the correct PyTorch wheel for your CUDA version. For CUDA 12.8, use the CUDA 12.8 commands in the setup section.

### `rclone` remote not found

Check configured remotes:

```bash
rclone listremotes
```

If your remote name is not `amity`, replace `amity` with your actual remote name in all commands.

### No PDFs were copied

Check that the input path exists and contains `.pdf` files:

```bash
find /path/to/pdf_folder -iname '*.pdf' | head
```

### MinerU is slow

Use GPU mode when available:

```bash
bash scripts/05_run_all.sh \
  --input /path/to/local/pdf_folder \
  --corpus-dir /workspace/projects/my_project/corpus \
  --device gpu \
  --rename-mode title
```

Also make sure MinerU is running once on the full folder instead of being restarted for each PDF.

---

## Recommended Workflow

For most projects, use the all-in-one command:

```bash
bash scripts/05_run_all.sh \
  --input /path/to/pdf_folder_or_google_drive_link \
  --corpus-dir /workspace/projects/my_project/corpus \
  --remote amity \
  --device gpu \
  --rename-mode title
```

After completion, use this folder in paper review:

```text
/my_project/corpus/extracted
```
