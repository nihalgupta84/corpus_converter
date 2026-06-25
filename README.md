# Corpus Converter

A reusable MinerU-based corpus conversion pipeline for research papers.

It converts a Google Drive folder or local folder of PDFs into a clean Markdown corpus with extracted figures and tables.

## Features

- Accepts Google Drive folder links.
- Accepts Google Drive folder IDs.
- Accepts local folders containing PDFs.
- Accepts a local single PDF.
- Ignores non-PDF files such as `.html`, `.htm`, `.url`, `.txt`, `.docx`, etc.
- Copies files only. No symlinks are created.
- Renames PDFs using detected paper titles when possible.
- Runs MinerU once on the full PDF folder for faster batch extraction.
- Converts MinerU raw output into a clean nested corpus layout.

## Final output layout

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

The final usable corpus path is:

target_corpus/extracted
Project structure
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
## Setup
### 1. Create conda environment
cd /workspace/projects/language/corpus_converter

conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main || true
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r || true

conda env create -f environment.yml
conda activate mineru

python -m pip install -U pip uv
python -m uv pip install -U "mineru[all]"
python -m pip install -r requirements-extra.txt
### 2. Check system
python scripts/00_check_system.py

**If GPU is required:**

python scripts/00_check_system.py --require-gpu
### 3. Fix PyTorch CUDA wheel if needed

If torch.cuda.is_available() is false, install the PyTorch wheel matching your driver.

**For CUDA 12.8:**

python -m pip uninstall -y torch torchvision torchaudio triton xformers
python -m pip freeze | grep -E '^nvidia-.*-cu13' | cut -d= -f1 | xargs -r python -m pip uninstall -y

python -m pip install --no-cache-dir \
  torch torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/cu128

**CPU fallback:**

python -m pip install --no-cache-dir \
  torch torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/cpu

**Verify again:**

python scripts/00_check_system.py
rclone setup for Google Drive

### Install rclone:

curl -fsSL https://rclone.org/install.sh | bash
rclone version

**Configure Google Drive remote:**

rclone config

**Recommended choices:**

n
name> __urs__
Storage> drive
client_id> press Enter
client_secret> press Enter
scope> 2
root_folder_id> press Enter
service_account_file> press Enter
Edit advanced config? n
Use auto config? n

On a server without browser access, choose manual authentication. Run the generated rclone authorize command on a local machine with browser access, then paste the returned token back into the server.

**Check remote:**

rclone lsd amity:
## Usage
**Option A: Google Drive folder**
cd /workspace/projects/language/corpus_converter
conda activate mineru

bash scripts/05_run_all.sh \
  --input "https://drive.google.com/drive/folders/YOUR_FOLDER_ID?usp=sharing" \
  --corpus-dir /workspace/projects/my_project/corpus \
  --remote amity \
  --device gpu \
  --rename-mode title
**Option B: Local folder**
cd /workspace/projects/language/corpus_converter
conda activate mineru

bash scripts/05_run_all.sh \
  --input /path/to/local/pdf_folder \
  --corpus-dir /workspace/projects/my_project/corpus \
  --device gpu \
  --rename-mode title
**Option C: CPU mode**
bash scripts/05_run_all.sh \
  --input /path/to/local/pdf_folder \
  --corpus-dir /workspace/projects/my_project/corpus \
  --device cpu \
  --rename-mode title
Step-by-step usage

### **Prepare PDFs:**

python scripts/01_prepare_inputs.py \
  --input /path/to/pdf_folder \
  --corpus-dir /workspace/projects/my_project/corpus \
  --rename-mode title

**Download Google Drive PDFs:**

bash scripts/02_download_gdrive_rclone.sh \
  "https://drive.google.com/drive/folders/YOUR_FOLDER_ID?usp=sharing" \
  /workspace/projects/my_project/corpus/downloaded \
  amity

### **Run MinerU:**

bash scripts/03_run_mineru_batch.sh \
  --corpus-dir /workspace/projects/my_project/corpus \
  --device gpu

### **Format final corpus:**

python scripts/04_format_mineru_output.py \
  --mineru-raw /workspace/projects/my_project/corpus/mineru_raw \
  --out-dir /workspace/projects/my_project/corpus/extracted \
  --force

### **Check status:**

bash scripts/99_status.sh /workspace/projects/my_project/corpus
Running with nohup
cd /workspace/projects/language/corpus_converter

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

### **Monitor:**

tail -f /workspace/projects/my_project/corpus/logs/nohup_corpus_converter_*.log
Notes

MinerU should run on the full folder, not one PDF at a time.

**Slow method:**

load MinerU models -> process 1 PDF -> shutdown -> repeat

**Fast method:**

load MinerU models once -> process entire raw_pdfs folder -> shutdown

_**This project uses the fast method.**_


