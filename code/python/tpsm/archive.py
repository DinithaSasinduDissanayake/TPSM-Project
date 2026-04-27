"""Archive completed TPSM output runs."""

from __future__ import annotations

import json
import os
import shutil
from pathlib import Path


PYTHON_REQUIRED_FILES = (
    "model_runs.csv",
    "pairwise_differences.csv",
    "analysis_ready_pairwise.csv",
    "run_manifest.json",
)


def _archive_root_for(output_dir: Path) -> Path:
    parts = output_dir.parts
    if len(parts) >= 2 and parts[-2] == "active":
        return output_dir.parent.parent / "archive" / output_dir.name
    return output_dir / "archive"


def _is_complete_python_run(run_dir: Path) -> bool:
    if (run_dir / "PAUSE").exists() or (run_dir / "STOP").exists():
        return False
    if not all((run_dir / name).exists() for name in PYTHON_REQUIRED_FILES):
        return False
    state_path = run_dir / "state" / "run_state.json"
    if not state_path.exists():
        return False
    try:
        state = json.loads(state_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return False
    return state.get("status") == "completed"


def _unique_destination(path: Path) -> Path:
    if not path.exists():
        return path
    index = 1
    while True:
        candidate = path.with_name(f"{path.name}_{index}")
        if not candidate.exists():
            return candidate
        index += 1


def archive_old_complete_runs(output_dir: str, keep_run_id: str) -> list[str]:
    """Move complete old runs from outputs/active/<runner> to outputs/archive/<runner>."""
    root = Path(output_dir)
    if not root.exists():
        return []
    archive_root = _archive_root_for(root)
    archive_root.mkdir(parents=True, exist_ok=True)

    moved: list[str] = []
    for child in sorted(root.iterdir()):
        if not child.is_dir() or child.name in {"archive", "active"}:
            continue
        if child.name == keep_run_id:
            continue
        if not _is_complete_python_run(child):
            continue
        dest = _unique_destination(archive_root / child.name)
        shutil.move(str(child), str(dest))
        moved.append(str(dest))
    return moved
