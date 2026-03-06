"""TPSM Pipeline - Output writing and JSON logging."""

import os
import json
import csv
import datetime
import threading
import pandas as pd
import time


def utc_now() -> str:
    """Return current UTC timestamp in ISO format."""
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def make_run_id() -> str:
    """Generate a run ID from current local time."""
    return datetime.datetime.now().strftime("%Y%m%dT%H%M%S")


class RunLogger:
    """JSON-line logger that writes to run_log.txt."""

    def __init__(self, output_dir: str, run_id: str):
        self._lock = threading.Lock()
        self.output_dir = output_dir
        self.run_id = run_id
        self.run_dir = os.path.join(output_dir, run_id)
        os.makedirs(self.run_dir, exist_ok=True)
        self.log_path = os.path.join(self.run_dir, "run_log.txt")
        self.pause_path = os.path.join(self.run_dir, "PAUSE")
        self.stop_path = os.path.join(self.run_dir, "STOP")

    def log(self, level: str, event: str, payload: dict | None = None):
        """Write a log event."""
        entry = {
            "timestamp_utc": utc_now(),
            "level": level,
            "event": event,
            "data": payload or {},
        }
        line = json.dumps(entry) + "\n"
        with self._lock:
            with open(self.log_path, "a") as f:
                f.write(line)

    def write_heartbeat(self, dataset_id: str):
        """Write a heartbeat file."""
        hb = {"timestamp_utc": utc_now(), "last_dataset": dataset_id}
        path = os.path.join(self.run_dir, "heartbeat.txt")
        with self._lock:
            with open(path, "w") as f:
                json.dump(hb, f)

    def write_manifest(self, cfg: dict, run_summary: dict):
        """Write run manifest JSON."""
        manifest = {
            "run_id": self.run_id,
            "config": cfg,
            "summary": run_summary,
        }
        path = os.path.join(self.run_dir, "run_manifest.json")
        with self._lock:
            with open(path, "w") as f:
                json.dump(manifest, f, indent=2, default=str)

    def control_paths(self) -> dict:
        """Return control file locations for this run."""
        return {
            "pause_file": self.pause_path,
            "stop_file": self.stop_path,
        }

    def wait_if_paused(self, poll_sec: float = 2.0) -> bool:
        """Wait while PAUSE exists. Return False if STOP is requested."""
        paused = False
        while os.path.exists(self.pause_path):
            if not paused:
                self.log("info", "run_paused", self.control_paths())
                paused = True
            if os.path.exists(self.stop_path):
                self.log("warning", "run_stop_requested", self.control_paths())
                return False
            time.sleep(poll_sec)
        if paused:
            self.log("info", "run_resumed", self.control_paths())
        return not os.path.exists(self.stop_path)


def write_csv_output(rows: list[dict], filepath: str):
    """Write a list of dicts to CSV."""
    if not rows:
        return
    df = pd.DataFrame(rows)
    df.to_csv(filepath, index=False)


def write_outputs(logger: RunLogger, model_runs: list, pairwise_rows: list):
    """Write final CSV outputs."""
    write_csv_output(model_runs, os.path.join(logger.run_dir, "model_runs.csv"))
    write_csv_output(
        pairwise_rows, os.path.join(logger.run_dir, "pairwise_differences.csv")
    )


def write_partial_outputs(logger: RunLogger, model_runs: list, pairwise_rows: list):
    """Write partial CSV outputs (crash protection)."""
    if model_runs:
        write_csv_output(
            model_runs, os.path.join(logger.run_dir, "model_runs.partial.csv")
        )
    if pairwise_rows:
        write_csv_output(
            pairwise_rows,
            os.path.join(logger.run_dir, "pairwise_differences.partial.csv"),
        )


def write_warnings_report(logger: RunLogger, all_warnings: list):
    """Write warnings summary and report."""
    if not all_warnings:
        return
    summary = {"total_warnings": len(all_warnings)}
    path_summary = os.path.join(logger.run_dir, "warnings_summary.json")
    with open(path_summary, "w") as f:
        json.dump(summary, f, indent=2)

    path_report = os.path.join(logger.run_dir, "warnings_report.json")
    with open(path_report, "w") as f:
        json.dump(all_warnings, f, indent=2, default=str)


def write_failed_datasets(logger: RunLogger, failed: list):
    """Write failed datasets CSV."""
    if not failed:
        return
    path = os.path.join(logger.run_dir, "failed_datasets.csv")
    write_csv_output(failed, path)
