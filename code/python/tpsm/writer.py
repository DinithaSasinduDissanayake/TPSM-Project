"""TPSM Pipeline - Output writing and JSON logging."""

import os
import json
import csv
import datetime
import threading
import pandas as pd


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

    @classmethod
    def from_run_dir(cls, run_dir: str):
        return cls(os.path.dirname(run_dir), os.path.basename(run_dir))

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

    def requested_action(self) -> str | None:
        """Return current control request if any."""
        if os.path.exists(self.stop_path):
            return "stop"
        if os.path.exists(self.pause_path):
            return "pause"
        return None

    def clear_pause(self) -> None:
        if os.path.exists(self.pause_path):
            os.remove(self.pause_path)

    def clear_stop(self) -> None:
        if os.path.exists(self.stop_path):
            os.remove(self.stop_path)


def write_csv_output(rows: list[dict], filepath: str):
    """Write a list of dicts to CSV."""
    if not rows:
        return
    df = pd.DataFrame(rows)
    df.to_csv(filepath, index=False)


def write_df_output(df: pd.DataFrame, filepath: str):
    """Write a dataframe to CSV if it has rows."""
    if df is None or df.empty:
        return
    df.to_csv(filepath, index=False)


def build_analysis_ready_pairwise(pair_df: pd.DataFrame) -> pd.DataFrame:
    """Create lab-friendly pairwise analysis table from benchmark output."""
    if pair_df is None or pair_df.empty:
        return pd.DataFrame()
    out = pair_df.copy()
    if "abs_difference_value" not in out.columns and "difference_value" in out.columns:
        out["abs_difference_value"] = out["difference_value"].abs()
    if (
        "model_pair" not in out.columns
        and {"single_model_name", "ensemble_model_name"}.issubset(out.columns)
    ):
        out["model_pair"] = (
            out["single_model_name"].astype(str)
            + "__vs__"
            + out["ensemble_model_name"].astype(str)
        )
    preferred_cols = [
        "comparison_id",
        "run_id",
        "task_type",
        "dataset_id",
        "dataset_source",
        "model_pair",
        "single_model_name",
        "ensemble_model_name",
        "metric_name",
        "higher_better",
        "single_metric_value",
        "ensemble_metric_value",
        "difference_value",
        "abs_difference_value",
        "ensemble_better",
        "split_method",
        "fold",
        "repeat_id",
        "train_rows",
        "test_rows",
        "dataset_total_rows",
        "dataset_total_cols",
        "difference_definition",
        "notes",
    ]
    present = [c for c in preferred_cols if c in out.columns]
    rest = [c for c in out.columns if c not in present]
    return out[present + rest]


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
