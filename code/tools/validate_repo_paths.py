#!/usr/bin/env python3
"""Validate repo paths after the TPSM reorganization."""

from __future__ import annotations

import importlib
import os
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


REQUIRED_PATHS = [
    "README.md",
    "AGENTS.md",
    "LESSONS_LEARNED.md",
    "TEAM_GUIDE.md",
    "code/python/tpsm/main.py",
    "code/python/tpsm/gui.py",
    "code/python/tpsm/archive.py",
    "code/r/main.R",
    "code/r/archive_outputs.R",
    "code/tools/launch_tpsm_gui.sh",
    "code/tools/open_tpsm_gui.sh",
    "config/production/datasets.yaml",
    "config/smoke/mini_smoke.yaml",
    "config/smoke/smoke_test.yaml",
    "config/debug/debug_ts_single.yaml",
    "presentation/browser-deck-shadcn/package.json",
    "presentation/slidev-deck/package.json",
    "outputs/active",
    "outputs/archive",
    "docs/report",
    "docs/methodology",
    "docs/validation",
    "docs/figures",
]


README_REQUIRED_SNIPPETS = [
    "python -m code.python.tpsm.main",
    "python -m code.python.tpsm.gui",
    "Rscript code/r/main.R",
    "presentation/browser-deck-shadcn",
    "presentation/slidev-deck",
    "outputs/active",
    "outputs/archive",
]


README_FORBIDDEN_REGEX = [
    r"python\s+-m\s+scripts\.python",
    r"Rscript\s+scripts/main\.R",
    r"config/datasets\.yaml",
    r"config/smoke_test\.yaml",
    r"docs/final_deck",
    r"(?<!presentation/)browser-deck-shadcn\s*/",
    r"(?<!presentation/)slidev-deck\s*/",
]


def check_required_paths(errors: list[str]) -> None:
    for rel in REQUIRED_PATHS:
        if not (ROOT / rel).exists():
            errors.append(f"missing path: {rel}")


def check_readme(errors: list[str]) -> None:
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    for snippet in README_REQUIRED_SNIPPETS:
        if snippet not in readme:
            errors.append(f"README missing snippet: {snippet}")
    for pattern in README_FORBIDDEN_REGEX:
        if re.search(pattern, readme):
            errors.append(f"README has stale path pattern: {pattern}")


def check_python_imports(errors: list[str]) -> None:
    sys.path.insert(0, str(ROOT))
    for module in [
        "code.python.tpsm.config",
        "code.python.tpsm.writer",
        "code.python.tpsm.archive",
    ]:
        try:
            importlib.import_module(module)
        except Exception as exc:  # noqa: BLE001 - validator reports exact import failure.
            errors.append(f"python import failed: {module}: {exc}")

    for module in ["code.python.tpsm.main", "code.python.tpsm.gui"]:
        proc = subprocess.run(
            [sys.executable, "-m", module, "--help"],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        if proc.returncode != 0 and "No module named 'sklearn'" not in proc.stderr:
            errors.append(f"python module help failed: {module}: {proc.stderr.strip()}")


def check_no_tracked_generated_bulk(errors: list[str]) -> None:
    proc = subprocess.run(
        ["git", "ls-files"],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    if proc.returncode != 0:
        errors.append(f"git ls-files failed: {proc.stderr.strip()}")
        return
    for path in proc.stdout.splitlines():
        if "/node_modules/" in path or "/dist/" in path:
            errors.append(f"generated bulk tracked by git: {path}")


def check_output_roots(errors: list[str]) -> None:
    for rel in ["outputs/active", "outputs/archive"]:
        path = ROOT / rel
        if not path.exists():
            errors.append(f"missing output root: {rel}")
        elif not path.is_dir():
            errors.append(f"output root is not directory: {rel}")


def main() -> int:
    errors: list[str] = []
    check_required_paths(errors)
    check_readme(errors)
    check_python_imports(errors)
    check_no_tracked_generated_bulk(errors)
    check_output_roots(errors)

    if errors:
        print("Repo path validation failed:")
        for error in errors:
            print(f" - {error}")
        return 1

    print("Repo path validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
