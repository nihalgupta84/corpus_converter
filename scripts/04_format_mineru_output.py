#!/usr/bin/env python3
import argparse
import hashlib
import json
import re
import shutil
from collections import defaultdict
from datetime import datetime
from pathlib import Path


def slugify(text: str, max_len: int = 180) -> str:
    text = text.replace("&", "and")
    text = re.sub(r"[^A-Za-z0-9._-]+", "_", text)
    text = re.sub(r"_+", "_", text).strip("._-")
    return text[:max_len] or "paper"


def sha256_file(path: Path | None):
    if not path or not path.exists():
        return None
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def load_json(path: Path | None):
    if not path:
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8", errors="ignore"))
    except Exception:
        return None


def find_main_md(auto_dir: Path):
    files = list(auto_dir.glob("*.md"))
    return max(files, key=lambda p: p.stat().st_size) if files else None


def find_content_json(auto_dir: Path):
    files = list(auto_dir.glob("*_content_list.json"))
    if not files:
        files = list(auto_dir.glob("*content_list*.json"))
    return files[0] if files else None


def find_origin_pdf(auto_dir: Path):
    files = list(auto_dir.glob("*_origin.pdf"))
    return files[0] if files else None


def collect_image_items(content_json: Path | None):
    data = load_json(content_json)
    if not isinstance(data, list):
        return []

    items = []

    for obj in data:
        if not isinstance(obj, dict):
            continue

        img_path = obj.get("img_path") or obj.get("image_path") or obj.get("path")
        if not img_path:
            continue

        typ = str(obj.get("type", "")).lower()

        page = obj.get("page_idx", obj.get("page", obj.get("page_no", 0)))
        try:
            page = int(page)
        except Exception:
            page = 0

        if typ == "table":
            label = "Table"
        elif typ in {"image", "figure"}:
            label = "Figure"
        else:
            label = "Picture"

        items.append(
            {
                "img_path": str(img_path),
                "page": page,
                "label": label,
                "type": typ,
            }
        )

    return items


def copy_images(auto_dir: Path, final_inner: Path, content_json: Path | None):
    image_map = {}
    counter = defaultdict(int)

    for item in collect_image_items(content_json):
        rel = item["img_path"]
        src = auto_dir / rel

        if not src.exists():
            src = auto_dir / "images" / Path(rel).name

        if not src.exists():
            continue

        page = item["page"]
        label = item["label"]
        idx = counter[(page, label)]
        counter[(page, label)] += 1

        ext = src.suffix.lower()
        if ext not in [".jpg", ".jpeg", ".png", ".webp"]:
            ext = ".jpg"

        new_name = f"_page_{page}_{label}_{idx}{ext}"
        shutil.copy2(src, final_inner / new_name)

        image_map[rel] = new_name
        image_map[f"images/{Path(rel).name}"] = new_name
        image_map[Path(rel).name] = new_name

    images_dir = auto_dir / "images"
    if images_dir.exists():
        fallback_idx = 0
        existing = set(image_map.values())

        for src in sorted(images_dir.iterdir()):
            if not src.is_file():
                continue
            if src.suffix.lower() not in [".jpg", ".jpeg", ".png", ".webp"]:
                continue
            if src.name in image_map:
                continue

            new_name = f"_page_unknown_Picture_{fallback_idx}{src.suffix.lower()}"
            fallback_idx += 1

            if new_name in existing:
                continue

            shutil.copy2(src, final_inner / new_name)
            image_map[src.name] = new_name
            image_map[f"images/{src.name}"] = new_name

    return image_map


def rewrite_markdown_images(text: str, image_map: dict):
    for old, new in sorted(image_map.items(), key=lambda x: len(x[0]), reverse=True):
        text = text.replace(old, new)
    return text


def format_one(paper_root: Path, out_dir: Path, force: bool = False):
    auto_dir = paper_root / "auto"
    if not auto_dir.exists():
        print(f"NO_AUTO: {paper_root}")
        return "failed"

    main_md = find_main_md(auto_dir)
    if not main_md:
        print(f"NO_MD: {paper_root}")
        return "failed"

    slug = slugify(paper_root.name)

    final_outer = out_dir / slug
    final_inner = final_outer / slug
    done_file = final_outer / ".done"

    if done_file.exists() and not force:
        print(f"SKIP: {slug}")
        return "skipped"

    if final_outer.exists() and force:
        shutil.rmtree(final_outer)

    final_inner.mkdir(parents=True, exist_ok=True)

    content_json = find_content_json(auto_dir)
    origin_pdf = find_origin_pdf(auto_dir)

    image_map = copy_images(auto_dir, final_inner, content_json)

    md_text = main_md.read_text(encoding="utf-8", errors="ignore")
    md_text = rewrite_markdown_images(md_text, image_map)

    final_md = final_inner / f"{slug}.md"
    final_md.write_text(md_text, encoding="utf-8")

    meta = {
        "paper_title": paper_root.name,
        "slug": slug,
        "created_at": datetime.now().isoformat(timespec="seconds"),
        "source_mineru_auto_dir": str(auto_dir),
        "source_markdown": str(main_md),
        "source_content_json": str(content_json) if content_json else None,
        "source_origin_pdf": str(origin_pdf) if origin_pdf else None,
        "origin_pdf_sha256": sha256_file(origin_pdf),
        "main_markdown": f"{slug}.md",
        "image_count": len(list(final_inner.glob("_page_*"))),
        "format": "clean_nested_mineru_corpus",
    }

    (final_inner / f"{slug}_meta.json").write_text(
        json.dumps(meta, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )

    done_file.write_text("done\n", encoding="utf-8")

    print(f"DONE: {slug} | images={meta['image_count']}")
    return "done"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--mineru-raw", required=True)
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    raw_dir = Path(args.mineru_raw).expanduser().resolve()
    out_dir = Path(args.out_dir).expanduser().resolve()

    if not raw_dir.exists():
        raise SystemExit(f"MinerU raw folder does not exist: {raw_dir}")

    out_dir.mkdir(parents=True, exist_ok=True)

    paper_roots = sorted([p for p in raw_dir.iterdir() if p.is_dir()])

    counts = {"done": 0, "skipped": 0, "failed": 0}

    print(f"Found MinerU paper folders: {len(paper_roots)}")

    for i, paper_root in enumerate(paper_roots, 1):
        print(f"[{i}/{len(paper_roots)}] {paper_root.name}")
        status = format_one(paper_root, out_dir, force=args.force)
        counts[status] += 1

    print("\nSummary")
    print(json.dumps(counts, indent=2))
    print(f"Output: {out_dir}")


if __name__ == "__main__":
    main()
