#!/usr/bin/env python3
"""
TPSM Pipeline - Main entry point.

Usage:
    python -m scripts.python.main --config config/smoke_test.yaml --output-dir outputs/py_test
    python -m scripts.python.main --config config/datasets.yaml --output-dir outputs/py_full --workers 4
"""

import argparse
import concurrent.futures
import os
import sys
import threading
import time
import warnings

# Ensure project root is on path
project_root = os.path.dirname(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
)
sys.path.insert(0, project_root)

from scripts.python.config import load_config
from scripts.python.pipeline import run_dataset_task
from scripts.python.writer import (
    RunLogger,
    make_run_id,
    write_outputs,
    write_partial_outputs,
    write_warnings_report,
    write_failed_datasets,
)


def main():
    parser = argparse.ArgumentParser(description="TPSM Pipeline (Python)")
    parser.add_argument("--config", required=True, help="Path to YAML config file")
    parser.add_argument(
        "--output-dir", default="outputs/python_run", help="Output directory"
    )
    parser.add_argument(
        "--workers", type=int, default=1, help="Number of parallel workers"
    )
    parser.add_argument(
        "--fast", action="store_true", help="Enable fast mode (auto-detect workers)"
    )
    parser.add_argument(
        "--timeout", type=int, default=300, help="Timeout per dataset (seconds)"
    )
    args = parser.parse_args()

    # Load config
    cfg = load_config(args.config)
    timeout_sec = args.timeout or cfg.get("timeout_seconds", 300)
    stop_on_fail = cfg.get("stop_on_first_fail", False)

    # Determine workers
    workers = args.workers
    if args.fast and workers <= 1:
        workers = max(1, (os.cpu_count() or 1) - 2)

    # Initialize run
    run_id = make_run_id()
    logger = RunLogger(args.output_dir, run_id)

    logger.log(
        "info",
        "run_start",
        {
            "run_id": run_id,
            "stop_on_fail": stop_on_fail,
            "timeout_sec": timeout_sec,
            "parallel_workers": workers,
            "fast_mode": args.fast,
            "python": True,
            "control_files": logger.control_paths(),
        },
    )

    # Build job list
    all_jobs = []
    for task in cfg["tasks"]:
        for ds in task["datasets"]:
            all_jobs.append({"task": task, "ds": ds})

    logger.log("info", "task_start", {"task": "ALL", "n_datasets": len(all_jobs)})

    # State
    model_runs = []
    pairwise_rows = []
    all_warnings = []
    failed_datasets = []
    total = len(all_jobs)
    result_lock = threading.Lock()
    completed = [0]

    def log_fn(level, event, payload):
        logger.log(level, event, payload)

    def collect_result(result):
        """Collect a single result into the aggregated lists."""
        with result_lock:
            i = completed[0]
            completed[0] += 1

            if result["failed"]:
                failed_datasets.append(
                    {
                        "dataset": result["dataset_id"],
                        "task": result["task_name"],
                        "error": result["error_message"],
                        "elapsed_sec": result["elapsed_sec"],
                    }
                )
                status = "failed"
                extra = {}
            else:
                model_runs.extend(result["model_runs"])
                pairwise_rows.extend(result["pairwise_rows"])
                all_warnings.extend(result["warnings"])
                status = "success"
                extra = {
                    "n_model_runs": len(result["model_runs"]),
                    "n_pairwise_rows": len(result["pairwise_rows"]),
                }

            logger.log(
                "info",
                "progress",
                {
                    "completed": i + 1,
                    "total": total,
                    "pct": round(100 * (i + 1) / total, 1),
                    "last_dataset": result["dataset_id"],
                    "last_status": status,
                    **extra,
                },
            )

            try:
                logger.write_heartbeat(result["dataset_id"])
            except Exception:
                pass

            return status == "success"

    def _run_single_job(job):
        """Run a single dataset job, honoring pause/stop before dataset start."""
        if not logger.wait_if_paused():
            return {
                "dataset_id": job["ds"]["id"],
                "task_name": job["task"]["name"],
                "model_runs": [],
                "pairwise_rows": [],
                "warnings": [],
                "failed": False,
                "error_message": None,
                "elapsed_sec": 0,
                "stopped": True,
            }

        result = run_dataset_task(
            job["task"],
            job["ds"],
            log_fn,
            timeout_sec,
            run_id=run_id,
            control_fn=logger.wait_if_paused,
        )
        result["stopped"] = False
        return result

    def _maybe_write_partial():
        """Write partial outputs every five collected results."""
        with result_lock:
            if completed[0] and completed[0] % 5 == 0:
                write_partial_outputs(logger, model_runs, pairwise_rows)

    if workers <= 1:
        for job in all_jobs:
            result = _run_single_job(job)
            if result.get("stopped"):
                logger.log(
                    "warning", "run_stopped", {"reason": "control_file_before_dataset"}
                )
                break

            success = collect_result(result)
            if not success and stop_on_fail:
                logger.log("error", "stopping_on_fail", {"dataset": job["ds"]["id"]})
                break

            try:
                _maybe_write_partial()
            except Exception:
                pass
    else:
        logger.log("info", "parallel_start", {"workers": workers, "total_jobs": total})
        with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as executor:
            future_to_job = {
                executor.submit(_run_single_job, job): job for job in all_jobs
            }
            for future in concurrent.futures.as_completed(future_to_job):
                job = future_to_job[future]
                try:
                    result = future.result()
                except Exception as exc:
                    result = {
                        "dataset_id": job["ds"]["id"],
                        "task_name": job["task"]["name"],
                        "model_runs": [],
                        "pairwise_rows": [],
                        "warnings": [],
                        "failed": True,
                        "error_message": str(exc),
                        "elapsed_sec": 0,
                        "stopped": False,
                    }

                if result.get("stopped"):
                    logger.log(
                        "warning",
                        "run_stopped",
                        {"reason": "control_file_before_dataset"},
                    )
                    break

                collect_result(result)
                try:
                    _maybe_write_partial()
                except Exception:
                    pass

    # Write final outputs
    write_outputs(logger, model_runs, pairwise_rows)
    write_warnings_report(logger, all_warnings)
    write_failed_datasets(logger, failed_datasets)

    # Run summary
    run_end_time = time.time()
    summary = {
        "model_run_rows": len(model_runs),
        "pairwise_rows": len(pairwise_rows),
        "total_datasets": total,
        "successful_datasets": total - len(failed_datasets),
        "failed_datasets": len(failed_datasets),
        "total_warnings": len(all_warnings),
        "run_id": run_id,
        "output_dir": logger.run_dir,
    }

    logger.log("info", "run_complete", summary)
    logger.write_manifest(
        {"config_path": args.config, "parallel_workers": workers}, summary
    )

    print(f"\n{'=' * 60}")
    print(f"Run complete: {run_id}")
    print(f"  Datasets: {summary['successful_datasets']}/{total} successful")
    print(f"  Failed:   {summary['failed_datasets']}")
    print(f"  Model runs: {summary['model_run_rows']}")
    print(f"  Pairwise:   {summary['pairwise_rows']}")
    print(f"  Output:     {logger.run_dir}")
    print(f"  Pause file: {logger.pause_path}")
    print(f"  Stop file:  {logger.stop_path}")
    print(f"{'=' * 60}")


if __name__ == "__main__":
    main()
