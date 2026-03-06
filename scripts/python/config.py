"""TPSM Pipeline - Configuration loading and validation."""
import yaml
import os
import sys
from dataclasses import dataclass, field
from typing import Optional


def load_config(config_path: str) -> dict:
    """Load and parse YAML configuration file."""
    with open(config_path) as f:
        raw = yaml.safe_load(f)

    cfg = {
        "stop_on_first_fail": raw.get("global", {}).get("stop_on_first_fail", False),
        "timeout_seconds": raw.get("global", {}).get("timeout_seconds", 300),
        "parallel_workers": raw.get("global", {}).get("parallel_workers", 1),
        "tasks": [],
    }

    task_types = ["classification", "regression", "timeseries"]
    for task_type in task_types:
        if task_type not in raw:
            continue
        task_raw = raw[task_type]
        task = {
            "name": task_type,
            "split": {
                "method": task_raw.get("split_method", "repeated_kfold"),
                "folds": task_raw.get("folds", 5),
                "repeats": task_raw.get("repeats", 1),
                "splits": task_raw.get("splits", 5),
            },
            "metrics": task_raw.get("metrics", []),
            "model_pairs": task_raw.get("model_pairs", []),
            "datasets": [],
        }
        for ds in task_raw.get("datasets", []):
            ds_cfg = {
                "id": ds["id"],
                "source": ds.get("source", "unknown"),
                "path": ds["path"],
                "url": ds.get("url"),
                "target": ds["target"],
                "time_col": ds.get("time_col"),
                "exog_cols": ds.get("exog_cols"),
                "separator": ds.get("separator"),
                "decimal": ds.get("decimal"),
                "header_names": ds.get("header_names"),
                "exclude_cols": ds.get("exclude_cols"),
                "zip_file": ds.get("zip_file"),
                "na_strings": ds.get("na_strings", "NA"),
                "max_rows": ds.get("max_rows"),
                "force_binary": ds.get("force_binary", False),
                "binary_positive_vals": ds.get("binary_positive_vals"),
                "binary_threshold": ds.get("binary_threshold"),
                "positive_class": ds.get("positive_class"),
                "rename_target_from": ds.get("rename_target_from"),
                "splits_override": ds.get("splits_override"),
                "max_ts_train_rows": ds.get("max_ts_train_rows"),
                "arima_max_order": ds.get("arima_max_order"),
                "arima_stepwise": ds.get("arima_stepwise"),
            }
            task["datasets"].append(ds_cfg)
        cfg["tasks"].append(task)

    return cfg


def validate_dataset(df, ds_cfg: dict, task_name: str, warnings_list: list):
    """Validate a loaded dataset, appending warnings to the list."""
    import pandas as pd

    def _format_pct(pct: float) -> str:
        if pct <= 0:
            return "0.0%"
        if pct < 0.1:
            return f"{pct:.3f}%"
        if pct < 1:
            return f"{pct:.2f}%"
        return f"{pct:.1f}%"

    target = ds_cfg["target"]
    if target not in df.columns:
        raise ValueError(f"Target column '{target}' not found in dataset '{ds_cfg['id']}'. Columns: {list(df.columns)}")

    if df[target].isna().all():
        raise ValueError(f"Target column '{target}' is entirely NA in '{ds_cfg['id']}'")

    # Check class imbalance for classification
    if task_name == "classification":
        vc = df[target].value_counts(normalize=True)
        min_pct = vc.min() * 100
        if min_pct < 5:
            warnings_list.append({
                "dataset": ds_cfg["id"],
                "issue": f"Severe class imbalance: minority class = {_format_pct(min_pct)}",
            })

    # Check constant columns
    for col in df.columns:
        if col == target:
            continue
        if df[col].nunique() <= 1:
            warnings_list.append({
                "dataset": ds_cfg["id"],
                "issue": f"Column '{col}' is constant",
            })
