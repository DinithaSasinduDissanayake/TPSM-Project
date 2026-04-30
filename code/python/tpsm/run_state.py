"""Persistent run state and checkpoint helpers for the Python pipeline."""

from __future__ import annotations

import datetime as _dt
import json
import os
from typing import Any

import pandas as pd
import yaml

from .data_loader import load_dataset
from .pipeline import preprocess_for_modeling
from .splits import make_splits


def utc_now() -> str:
    return _dt.datetime.now(_dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def atomic_write_json(path: str, payload: dict[str, Any]) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = f"{path}.tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2, default=str)
    os.replace(tmp, path)


def load_json(path: str) -> dict[str, Any]:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def write_yaml_snapshot(path: str, cfg: dict[str, Any]) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        yaml.safe_dump(cfg, f, sort_keys=False)


def make_dataset_key(task_name: str, dataset_id: str) -> str:
    return f"{task_name}::{dataset_id}"


def make_unit_id(task_name: str, dataset_id: str, split_info: dict[str, Any]) -> str:
    return (
        f"{task_name}::{dataset_id}::"
        f"r{split_info['repeat_id']}::f{split_info['fold']}::i{split_info.get('split_index', 0)}"
    )


def build_execution_plan(cfg: dict[str, Any]) -> list[dict[str, Any]]:
    """Materialize the exact split-level execution plan for a config."""
    plan: list[dict[str, Any]] = []
    task_order = ["classification", "regression", "timeseries"]
    tasks_by_name = {task["name"]: task for task in cfg["tasks"]}

    for task_name in task_order:
        task = tasks_by_name.get(task_name)
        if not task:
            continue
        for ds_cfg in task["datasets"]:
            df = load_dataset(ds_cfg)
            df = preprocess_for_modeling(df, ds_cfg["target"], task_name, ds_cfg)
            split_cfg = dict(task["split"])
            if task_name == "timeseries" and ds_cfg.get("splits_override"):
                split_cfg["splits"] = ds_cfg["splits_override"]
            splits = make_splits(
                task_name, df, split_cfg, ds_cfg["target"], ds_cfg["id"]
            )
            dataset_key = make_dataset_key(task_name, ds_cfg["id"])
            total_splits = len(splits)
            for split_index, split_info in enumerate(splits, start=1):
                split_info = dict(split_info)
                split_info["split_index"] = split_index
                plan.append(
                    {
                        "unit_id": make_unit_id(task_name, ds_cfg["id"], split_info),
                        "dataset_key": dataset_key,
                        "task_name": task_name,
                        "dataset_id": ds_cfg["id"],
                        "split_index": split_index,
                        "total_splits_for_dataset": total_splits,
                        "fold": split_info["fold"],
                        "repeat_id": split_info["repeat_id"],
                        "status": "pending",
                    }
                )
    return plan


def _progress_from_state(state: dict[str, Any]) -> dict[str, Any]:
    units = state["units"]
    datasets = state["datasets"]
    total_units = len(units)
    completed_units = sum(1 for u in units if u["status"] == "completed")
    failed_units = sum(1 for u in units if u["status"] == "failed")
    running_units = sum(1 for u in units if u["status"] == "running")
    total_datasets = len(datasets)
    completed_datasets = sum(
        1 for d in datasets.values() if d["completed_units"] >= d["total_units"]
    )
    failed_datasets = sum(1 for d in datasets.values() if d["status"] == "failed")
    pct = round((completed_units / total_units) * 100.0, 2) if total_units else 0.0
    return {
        "total_units": total_units,
        "completed_units": completed_units,
        "failed_units": failed_units,
        "running_units": running_units,
        "total_datasets": total_datasets,
        "completed_datasets": completed_datasets,
        "failed_datasets": failed_datasets,
        "pct_complete": pct,
    }


def create_initial_state(
    *,
    run_id: str,
    run_dir: str,
    config_snapshot_path: str,
    config_source_path: str,
    cfg: dict[str, Any],
) -> dict[str, Any]:
    units = build_execution_plan(cfg)
    datasets: dict[str, Any] = {}
    for unit in units:
        dkey = unit["dataset_key"]
        ds = datasets.setdefault(
            dkey,
            {
                "dataset_key": dkey,
                "task_name": unit["task_name"],
                "dataset_id": unit["dataset_id"],
                "total_units": unit["total_splits_for_dataset"],
                "completed_units": 0,
                "status": "pending",
            },
        )
        ds["total_units"] = unit["total_splits_for_dataset"]

    state = {
        "run_id": run_id,
        "run_dir": run_dir,
        "status": "pending",
        "created_at_utc": utc_now(),
        "updated_at_utc": utc_now(),
        "config_snapshot_path": config_snapshot_path,
        "config_source_path": config_source_path,
        "worker_mode": "sequential",
        "current_unit_id": None,
        "last_completed_unit_id": None,
        "units": units,
        "datasets": datasets,
        "progress": {},
        "runner_pid": None,
        "runner_started_at_utc": None,
        "runner_stopped_at_utc": None,
    }
    state["progress"] = _progress_from_state(state)
    return state


class RunStateStore:
    def __init__(self, run_dir: str):
        self.run_dir = run_dir
        self.state_dir = os.path.join(run_dir, "state")
        self.state_path = os.path.join(self.state_dir, "run_state.json")
        self.model_parts_dir = os.path.join(self.state_dir, "model_runs_parts")
        self.pairwise_parts_dir = os.path.join(self.state_dir, "pairwise_parts")
        self.warning_parts_dir = os.path.join(self.state_dir, "warning_parts")
        os.makedirs(self.model_parts_dir, exist_ok=True)
        os.makedirs(self.pairwise_parts_dir, exist_ok=True)
        os.makedirs(self.warning_parts_dir, exist_ok=True)

    def exists(self) -> bool:
        return os.path.exists(self.state_path)

    def load(self) -> dict[str, Any]:
        return load_json(self.state_path)

    def save(self, state: dict[str, Any]) -> None:
        state["updated_at_utc"] = utc_now()
        state["progress"] = _progress_from_state(state)
        atomic_write_json(self.state_path, state)

    def mark_resumable(self, state: dict[str, Any]) -> dict[str, Any]:
        for unit in state["units"]:
            if unit["status"] == "running":
                unit["status"] = "pending"
        if state["status"] == "running":
            state["status"] = "paused"
        state["current_unit_id"] = None
        return state

    def set_runner_started(self, state: dict[str, Any], pid: int | None) -> None:
        state["runner_pid"] = pid
        state["runner_started_at_utc"] = utc_now()
        state["runner_stopped_at_utc"] = None
        if state["status"] in ("pending", "paused", "stopped"):
            state["status"] = "running"
        self.save(state)

    def set_runner_stopped(self, state: dict[str, Any], status: str) -> None:
        state["status"] = status
        state["runner_stopped_at_utc"] = utc_now()
        current_unit_id = state.get("current_unit_id")
        if current_unit_id:
            for unit in state["units"]:
                if unit["unit_id"] == current_unit_id and unit["status"] == "running":
                    unit["status"] = "pending"
                    dataset = state["datasets"].get(unit["dataset_key"])
                    if dataset and dataset["status"] == "running":
                        dataset["status"] = status
                    break
        for dataset in state["datasets"].values():
            if dataset["status"] == "running" and status in ("paused", "stopped"):
                dataset["status"] = status
        state["current_unit_id"] = None
        self.save(state)

    def mark_unit_running(self, state: dict[str, Any], unit_id: str) -> None:
        for unit in state["units"]:
            if unit["unit_id"] == unit_id:
                unit["status"] = "running"
                state["current_unit_id"] = unit_id
                dkey = unit["dataset_key"]
                state["datasets"][dkey]["status"] = "running"
                break
        self.save(state)

    def mark_unit_completed(self, state: dict[str, Any], unit_id: str) -> None:
        for unit in state["units"]:
            if unit["unit_id"] == unit_id:
                unit["status"] = "completed"
                dkey = unit["dataset_key"]
                dataset = state["datasets"][dkey]
                dataset["completed_units"] += 1
                dataset["status"] = (
                    "completed"
                    if dataset["completed_units"] >= dataset["total_units"]
                    else "running"
                )
                state["last_completed_unit_id"] = unit_id
                state["current_unit_id"] = None
                break
        self.save(state)

    def mark_dataset_failed(
        self, state: dict[str, Any], task_name: str, dataset_id: str
    ) -> None:
        dkey = make_dataset_key(task_name, dataset_id)
        dataset = state["datasets"].get(dkey)
        if dataset:
            dataset["status"] = "failed"
        for unit in state["units"]:
            if unit["dataset_key"] == dkey and unit["status"] == "running":
                unit["status"] = "pending"
        state["current_unit_id"] = None
        self.save(state)

    def completed_unit_ids_for_dataset(
        self, state: dict[str, Any], task_name: str, dataset_id: str
    ) -> set[str]:
        dkey = make_dataset_key(task_name, dataset_id)
        return {
            unit["unit_id"]
            for unit in state["units"]
            if unit["dataset_key"] == dkey and unit["status"] == "completed"
        }

    def write_split_parts(
        self,
        unit_id: str,
        model_rows: list[dict[str, Any]],
        pairwise_rows: list[dict[str, Any]],
        warnings_list: list[Any],
    ) -> None:
        if model_rows:
            pd.DataFrame(model_rows).to_csv(
                os.path.join(self.model_parts_dir, f"{unit_id}.csv"), index=False
            )
        if pairwise_rows:
            pd.DataFrame(pairwise_rows).to_csv(
                os.path.join(self.pairwise_parts_dir, f"{unit_id}.csv"), index=False
            )
        if warnings_list:
            atomic_write_json(
                os.path.join(self.warning_parts_dir, f"{unit_id}.json"),
                {"warnings": warnings_list},
            )

    def aggregate_outputs(self) -> tuple[pd.DataFrame, pd.DataFrame, list[Any]]:
        model_frames = []
        pair_frames = []
        warnings_list: list[Any] = []

        for name in sorted(os.listdir(self.model_parts_dir)):
            if name.endswith(".csv"):
                model_frames.append(
                    pd.read_csv(os.path.join(self.model_parts_dir, name))
                )
        for name in sorted(os.listdir(self.pairwise_parts_dir)):
            if name.endswith(".csv"):
                pair_frames.append(
                    pd.read_csv(os.path.join(self.pairwise_parts_dir, name))
                )
        for name in sorted(os.listdir(self.warning_parts_dir)):
            if name.endswith(".json"):
                payload = load_json(os.path.join(self.warning_parts_dir, name))
                warnings_list.extend(payload.get("warnings", []))

        model_df = (
            pd.concat(model_frames, ignore_index=True)
            if model_frames
            else pd.DataFrame()
        )
        pair_df = (
            pd.concat(pair_frames, ignore_index=True) if pair_frames else pd.DataFrame()
        )

        if not model_df.empty:
            if "model_run_id" in model_df.columns:
                model_df = model_df.drop_duplicates(
                    subset=["model_run_id"]
                ).reset_index(drop=True)
            elif "run_id" in model_df.columns:
                model_df = model_df.drop_duplicates(subset=["run_id"]).reset_index(
                    drop=True
                )
        if not pair_df.empty and "comparison_id" in pair_df.columns:
            pair_df = pair_df.drop_duplicates(subset=["comparison_id"]).reset_index(
                drop=True
            )

        return model_df, pair_df, warnings_list
