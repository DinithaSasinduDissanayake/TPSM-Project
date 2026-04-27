#!/usr/bin/env python3
"""
TPSM Pipeline - Resumable main entry point.

Usage:
    python -m code.python.tpsm.main --config config/smoke/mini_smoke.yaml --output-dir outputs/active/python
    python -m code.python.tpsm.main --resume-run outputs/active/python/20260309T120000
"""

from __future__ import annotations

import argparse
import os
import sys
from typing import Any

import pandas as pd

project_root = os.path.dirname(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
)
sys.path.insert(0, project_root)

from code.python.tpsm.archive import archive_old_complete_runs
from code.python.tpsm.config import load_config
from code.python.tpsm.pipeline import run_dataset_task
from code.python.tpsm.run_state import (
    RunStateStore,
    create_initial_state,
    write_yaml_snapshot,
)
from code.python.tpsm.writer import (
    RunLogger,
    build_analysis_ready_pairwise,
    make_run_id,
    write_df_output,
    write_failed_datasets,
    write_warnings_report,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="TPSM Pipeline (Python, resumable)")
    parser.add_argument("--config", help="Path to YAML config file")
    parser.add_argument(
        "--output-dir", default="outputs/active/python", help="Output directory root"
    )
    parser.add_argument(
        "--timeout", type=int, default=300, help="Timeout per dataset (seconds)"
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=1,
        help="Ignored in resumable v1; runner is sequential",
    )
    parser.add_argument("--fast", action="store_true", help="Ignored in resumable v1")
    parser.add_argument("--resume-run", help="Resume an existing run directory")
    parser.add_argument(
        "--run-id", help="Optional fixed run id for externally orchestrated launches"
    )
    args = parser.parse_args()
    if not args.resume_run and not args.config:
        parser.error("either --config or --resume-run is required")
    return args


def _iter_tasks(cfg: dict[str, Any]):
    for task in cfg["tasks"]:
        for ds in task["datasets"]:
            yield task, ds


def _finalize_outputs(logger: RunLogger, store: RunStateStore) -> dict[str, Any]:
    model_df, pair_df, warnings_list = store.aggregate_outputs()
    write_df_output(model_df, os.path.join(logger.run_dir, "model_runs.csv"))
    write_df_output(pair_df, os.path.join(logger.run_dir, "pairwise_differences.csv"))
    write_df_output(
        build_analysis_ready_pairwise(pair_df),
        os.path.join(logger.run_dir, "analysis_ready_pairwise.csv"),
    )
    write_warnings_report(logger, warnings_list)
    failed_path = os.path.join(store.state_dir, "failed_datasets.json")
    failed_rows = []
    if os.path.exists(failed_path):
        import json

        with open(failed_path, "r", encoding="utf-8") as f:
            failed_rows = json.load(f)
    write_failed_datasets(logger, failed_rows)
    dataset_summary_path = os.path.join(store.state_dir, "dataset_cleaning_summary.json")
    dataset_summary_rows = []
    if os.path.exists(dataset_summary_path):
        import json

        with open(dataset_summary_path, "r", encoding="utf-8") as f:
            dataset_summary_rows = json.load(f)
    write_df_output(
        pd.DataFrame(dataset_summary_rows),
        os.path.join(logger.run_dir, "dataset_cleaning_summary.csv"),
    )
    return {
        "model_run_rows": int(len(model_df)),
        "pairwise_rows": int(len(pair_df)),
        "total_warnings": len(warnings_list),
        "failed_rows": len(failed_rows),
        "dataset_summary_rows": len(dataset_summary_rows),
    }


def _append_dataset_summary(store: RunStateStore, row: dict[str, Any]) -> None:
    import json

    path = os.path.join(store.state_dir, "dataset_cleaning_summary.json")
    rows = []
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            rows = json.load(f)
    rows = [r for r in rows if r.get("task_type") != row.get("task_type") or r.get("dataset_id") != row.get("dataset_id")]
    rows.append(row)
    tmp = f"{path}.tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(rows, f, indent=2)
    os.replace(tmp, path)


def _append_failed_dataset(store: RunStateStore, row: dict[str, Any]) -> None:
    import json

    path = os.path.join(store.state_dir, "failed_datasets.json")
    rows = []
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            rows = json.load(f)
    rows.append(row)
    tmp = f"{path}.tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(rows, f, indent=2)
    os.replace(tmp, path)


def _control_action(logger: RunLogger) -> str:
    return logger.requested_action() or "run"


def _load_or_init_run(args: argparse.Namespace):
    if args.resume_run:
        run_dir = os.path.abspath(args.resume_run)
        logger = RunLogger.from_run_dir(run_dir)
        store = RunStateStore(run_dir)
        if not store.exists():
            raise FileNotFoundError(f"No resumable state found in {run_dir}")
        state = store.mark_resumable(store.load())
        store.save(state)
        cfg = load_config(state["config_snapshot_path"])
        return logger, store, state, cfg

    cfg = load_config(args.config)
    run_id = args.run_id or make_run_id()
    logger = RunLogger(args.output_dir, run_id)
    store = RunStateStore(logger.run_dir)
    snapshot_path = os.path.join(logger.run_dir, "config_snapshot.yaml")
    write_yaml_snapshot(snapshot_path, _config_to_yaml_like(cfg))
    state = create_initial_state(
        run_id=run_id,
        run_dir=logger.run_dir,
        config_snapshot_path=snapshot_path,
        config_source_path=os.path.abspath(args.config),
        cfg=cfg,
    )
    store.save(state)
    return logger, store, state, cfg


def _config_to_yaml_like(cfg: dict[str, Any]) -> dict[str, Any]:
    """Serialize loaded config back to yaml-like shape for durable snapshots."""
    out: dict[str, Any] = {
        "global": {
            "stop_on_first_fail": cfg.get("stop_on_first_fail", False),
            "timeout_seconds": cfg.get("timeout_seconds", 300),
            "parallel_workers": 1,
        }
    }
    for task in cfg["tasks"]:
        block = {
            "split_method": task["split"]["method"],
            "folds": task["split"].get("folds"),
            "repeats": task["split"].get("repeats"),
            "splits": task["split"].get("splits"),
            "metrics": task.get("metrics", []),
            "model_pairs": task.get("model_pairs", []),
            "datasets": task.get("datasets", []),
        }
        out[task["name"]] = block
    return out


def main() -> int:
    args = parse_args()
    logger, store, state, cfg = _load_or_init_run(args)

    # Clear stale control files from previous run/resume so they don't re-trigger immediately
    if args.resume_run:
        logger.clear_pause()
        logger.clear_stop()
    else:
        logger.clear_pause()
        logger.clear_stop()

    logger.log(
        "info",
        "run_start",
        {
            "run_id": state["run_id"],
            "python": True,
            "timeout_sec": args.timeout,
            "worker_mode": "sequential",
            "control_files": logger.control_paths(),
            "resume": bool(args.resume_run),
        },
    )

    if args.workers > 1 or args.fast:
        logger.log(
            "warning",
            "sequential_only_mode",
            {
                "requested_workers": args.workers,
                "fast_mode": args.fast,
                "message": "Resumable v1 runs sequentially for reliable checkpoint/resume.",
            },
        )

    state = store.load()
    store.set_runner_started(state, os.getpid())
    stop_on_fail = cfg.get("stop_on_first_fail", False)

    if _control_action(logger) == "pause":
        logger.log("info", "run_paused", {"reason": "pause_requested_before_start"})
        state = store.load()
        store.set_runner_stopped(state, "paused")
        return 0
    if _control_action(logger) == "stop":
        logger.log("info", "run_stopped", {"reason": "stop_requested_before_start"})
        state = store.load()
        store.set_runner_stopped(state, "stopped")
        return 0

    for task, ds in _iter_tasks(cfg):
        state = store.load()
        completed_unit_ids = store.completed_unit_ids_for_dataset(
            state, task["name"], ds["id"]
        )

        def on_split_complete(meta, rows, pair_rows, split_warnings):
            logger.log(
                "debug",
                "split_checkpoint",
                {
                    **meta,
                    "n_model_runs": len(rows),
                    "n_pairwise_rows": len(pair_rows),
                    "n_warnings": len(split_warnings),
                },
            )
            store.write_split_parts(meta["unit_id"], rows, pair_rows, split_warnings)
            current = store.load()
            store.mark_unit_completed(current, meta["unit_id"])

        def on_split_start(meta):
            current = store.load()
            store.mark_unit_running(current, meta["unit_id"])

        def control_fn():
            return _control_action(logger)

        dataset_result = run_dataset_task(
            task,
            ds,
            logger.log,
            args.timeout,
            run_id=state["run_id"],
            control_fn=control_fn,
            completed_unit_ids=completed_unit_ids,
            on_split_start=on_split_start,
            on_split_complete=on_split_complete,
        )

        if dataset_result.get("dataset_summary"):
            _append_dataset_summary(store, dataset_result["dataset_summary"])

        state = store.load()
        if dataset_result.get("stopped"):
            status = (
                "paused" if dataset_result.get("stop_reason") == "pause" else "stopped"
            )
            logger.log("info", f"run_{status}", {"reason": f"{status}_after_split"})
            store.set_runner_stopped(state, status)
            summary = _finalize_outputs(logger, store)
            logger.write_manifest(
                {"config_path": state["config_snapshot_path"], "parallel_workers": 1},
                summary,
            )
            return 0

        if dataset_result["failed"]:
            logger.log(
                "error",
                "dataset_failed",
                {
                    "task": task["name"],
                    "dataset": ds["id"],
                    "error_message": dataset_result["error_message"],
                },
            )
            store.mark_dataset_failed(state, task["name"], ds["id"])
            _append_failed_dataset(
                store,
                {
                    "dataset": ds["id"],
                    "task": task["name"],
                    "error": dataset_result["error_message"],
                    "elapsed_sec": dataset_result["elapsed_sec"],
                },
            )
            if stop_on_fail:
                store.set_runner_stopped(store.load(), "failed")
                summary = _finalize_outputs(logger, store)
                logger.write_manifest(
                    {
                        "config_path": state["config_snapshot_path"],
                        "parallel_workers": 1,
                    },
                    summary,
                )
                return 1

    state = store.load()
    store.set_runner_stopped(state, "completed")
    summary = _finalize_outputs(logger, store)
    summary["run_id"] = state["run_id"]
    summary["output_dir"] = logger.run_dir
    logger.log("info", "run_complete", summary)
    logger.write_manifest(
        {"config_path": state["config_snapshot_path"], "parallel_workers": 1}, summary
    )
    archive_old_complete_runs(logger.output_dir, keep_run_id=state["run_id"])

    print(f"\n{'=' * 60}")
    print(f"Run complete: {state['run_id']}")
    print(f"  Model runs: {summary['model_run_rows']}")
    print(f"  Pairwise:   {summary['pairwise_rows']}")
    print(f"  Output:     {logger.run_dir}")
    print(f"  Pause file: {logger.pause_path}")
    print(f"  Stop file:  {logger.stop_path}")
    print(f"{'=' * 60}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
