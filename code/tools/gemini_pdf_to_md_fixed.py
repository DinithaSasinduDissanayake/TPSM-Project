#!/usr/bin/env python3
"""Canonical Gemini PDF -> Markdown batch wrapper.

This wrapper cleans slide-folder selection before invoking the shared Gemini
converter:
- skips duplicate copies like `* File.pdf`
- optionally archives skipped duplicates into `_duplicates/`
- reports Gemini key count from env file
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


SKILL_SCRIPT = Path.home() / ".codex" / "skills" / "pdf-to-markdown" / "scripts" / "gemini_pdf_to_md.py"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Canonical Gemini PDF -> Markdown wrapper")
    p.add_argument(
        "--root",
        type=Path,
        required=True,
        help="Folder to scan for PDFs.",
    )
    p.add_argument(
        "--env-file",
        type=Path,
        default=Path(".env"),
        help="Env file with Gemini API keys.",
    )
    p.add_argument(
        "--archive-duplicates",
        action="store_true",
        help="Move duplicate PDF copies into _duplicates/ before conversion.",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="Show canonical/duplicate selection and stop.",
    )
    return p.parse_args()


def load_env(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    if not path.exists():
        return out
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        out[k.strip()] = v.strip().strip('"').strip("'")
    return out


def count_gemini_keys(env_map: dict[str, str]) -> tuple[int, list[str]]:
    keys: list[str] = []
    csv_keys = env_map.get("GEMINI_API_KEYS", "")
    if csv_keys:
        keys.extend([k.strip() for k in csv_keys.split(",") if k.strip()])
    for single in ("GEMINI_API_KEY", "GOOGLE_API_KEY"):
        val = env_map.get(single, "").strip()
        if val:
            keys.append(val)
    for k, v in env_map.items():
        if re.fullmatch(r"GEMINI_API_KEY_(\d+)", k) and v.strip():
            keys.append(v.strip())
    dedup = []
    seen = set()
    for k in keys:
        if k not in seen:
            seen.add(k)
            dedup.append(k)
    return len(dedup), dedup


def canonicalize_pdf_name(name: str) -> str:
    return re.sub(r"\s+File(?=\.pdf$)", "", name, flags=re.IGNORECASE)


def discover_pdfs(root: Path) -> tuple[list[Path], list[Path]]:
    all_pdfs = sorted(root.rglob("*.pdf"))
    canonical: list[Path] = []
    duplicates: list[Path] = []
    seen_keys: set[str] = set()

    for pdf in all_pdfs:
        if pdf.name.endswith(".level2.gemini.md"):
            continue
        if "_duplicates" in pdf.parts:
            continue
        key = str(pdf.with_name(canonicalize_pdf_name(pdf.name)).resolve())
        if pdf.name != canonicalize_pdf_name(pdf.name):
            duplicates.append(pdf)
            continue
        if key in seen_keys:
            duplicates.append(pdf)
            continue
        seen_keys.add(key)
        canonical.append(pdf)

    return canonical, duplicates


def archive_duplicates(root: Path, duplicates: list[Path]) -> list[Path]:
    if not duplicates:
        return []
    archive_dir = root / "_duplicates"
    archive_dir.mkdir(parents=True, exist_ok=True)
    moved: list[Path] = []
    for pdf in duplicates:
        dest = archive_dir / pdf.name
        if dest.exists():
            dest.unlink()
        shutil.move(str(pdf), str(dest))
        moved.append(dest)
        md = pdf.with_name(f"{pdf.stem}.level2.gemini.md")
        if md.exists():
            md_dest = archive_dir / md.name
            if md_dest.exists():
                md_dest.unlink()
            shutil.move(str(md), str(md_dest))
    return moved


def main() -> int:
    args = parse_args()
    env_map = load_env(args.env_file)
    key_count, _ = count_gemini_keys(env_map)
    canonical, duplicates = discover_pdfs(args.root)

    print(f"Gemini key vars: {key_count}")
    print(f"Canonical PDFs: {len(canonical)}")
    print(f"Duplicate PDFs: {len(duplicates)}")

    if args.dry_run:
        for pdf in canonical:
            print(f"CANONICAL {pdf.name}")
        for pdf in duplicates:
            print(f"DUPLICATE  {pdf.name}")
        return 0

    if args.archive_duplicates:
        moved = archive_duplicates(args.root, duplicates)
        print(f"Archived duplicates: {len(moved)}")

    if not canonical:
        print("No canonical PDFs found.")
        return 2

    if not SKILL_SCRIPT.exists():
        print(f"Missing Gemini skill script: {SKILL_SCRIPT}", file=sys.stderr)
        return 1

    cmd = [
        sys.executable,
        str(SKILL_SCRIPT),
        "--env-file",
        str(args.env_file),
        *[str(p) for p in canonical],
    ]
    return subprocess.call(cmd)


if __name__ == "__main__":
    raise SystemExit(main())
