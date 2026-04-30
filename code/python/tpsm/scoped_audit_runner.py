#!/usr/bin/env python3
"""Run near-production scoped audits: one task + one dataset + one model pair per run."""
from __future__ import annotations

import argparse
import json
import math
import os
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from typing import Any

import pandas as pd
import yaml


@dataclass(frozen=True)
class Unit:
    task_name: str
    dataset_id: str
    single_model: str
    ensemble_model: str


def load_yaml(path: str) -> dict[str, Any]:
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def task_split_block(task_name: str, src_task: dict[str, Any], near_profile: str) -> dict[str, Any]:
    block: dict[str, Any] = {}
    if task_name in ("classification", "regression"):
        block["split_method"] = src_task.get("split_method", "repeated_kfold")
        if near_profile in ("k10r3_ts10", "k10r3_ts3"):
            block["folds"] = 10
            block["repeats"] = 3
        elif near_profile == "k10r2_ts8":
            block["folds"] = 10
            block["repeats"] = 2
        elif near_profile == "k8r3_ts10":
            block["folds"] = 8
            block["repeats"] = 3
        else:
            raise ValueError(f"Unknown near profile: {near_profile}")
    else:
        block["split_method"] = src_task.get("split_method", "rolling_origin")
        if near_profile == "k10r3_ts10":
            block["splits"] = 10
        elif near_profile == "k10r3_ts3":
            block["splits"] = 3
        elif near_profile == "k10r2_ts8":
            block["splits"] = 8
        elif near_profile == "k8r3_ts10":
            block["splits"] = 10
        else:
            raise ValueError(f"Unknown near profile: {near_profile}")
    return block


def build_units(cfg: dict[str, Any], tasks: list[str] | None, dataset_filter: set[str] | None) -> list[Unit]:
    out: list[Unit] = []
    task_names = ["classification", "regression", "timeseries"]
    for task_name in task_names:
        if tasks and task_name not in tasks:
            continue
        task = cfg.get(task_name)
        if not task:
            continue
        for ds in task.get("datasets", []):
            ds_id = ds["id"]
            if dataset_filter and ds_id not in dataset_filter:
                continue
            for pair in task.get("model_pairs", []):
                out.append(
                    Unit(
                        task_name=task_name,
                        dataset_id=ds_id,
                        single_model=pair["single"],
                        ensemble_model=pair["ensemble"],
                    )
                )
    return out


def make_scoped_config(
    base_cfg: dict[str, Any],
    unit: Unit,
    near_profile: str,
    timeout_seconds: int,
) -> dict[str, Any]:
    src_task = base_cfg[unit.task_name]
    ds = next(d for d in src_task["datasets"] if d["id"] == unit.dataset_id)
    task_block = task_split_block(unit.task_name, src_task, near_profile)
    task_block["metrics"] = src_task.get("metrics", [])
    task_block["model_pairs"] = [{"single": unit.single_model, "ensemble": unit.ensemble_model}]
    task_block["datasets"] = [ds]
    return {
        "global": {
            "stop_on_first_fail": False,
            "timeout_seconds": timeout_seconds,
            "parallel_workers": 1,
        },
        unit.task_name: task_block,
    }


def _sample_positions(n: int) -> list[int]:
    if n <= 0:
        return []
    pos = sorted({0, n // 2, n - 1})
    return [p for p in pos if 0 <= p < n]


def _is_finite_or_na(v: Any) -> bool:
    if pd.isna(v):
        return True
    try:
        return math.isfinite(float(v))
    except Exception:
        return False


def audit_run(run_dir: str, task_name: str, dataset_id: str, single_model: str, ensemble_model: str) -> dict[str, Any]:
    model_path = os.path.join(run_dir, "model_runs.csv")
    pair_path = os.path.join(run_dir, "pairwise_differences.csv")
    fail_path = os.path.join(run_dir, "failed_datasets.csv")

    mr = pd.read_csv(model_path) if os.path.exists(model_path) else pd.DataFrame()
    pw = pd.read_csv(pair_path) if os.path.exists(pair_path) else pd.DataFrame()
    failed = pd.read_csv(fail_path) if os.path.exists(fail_path) else pd.DataFrame()

    failures: list[str] = []
    warnings: list[str] = []

    if not failed.empty:
        failures.append("failed_datasets.csv has rows")

    if mr.empty:
        failures.append("model_runs.csv is empty")
    if pw.empty:
        failures.append("pairwise_differences.csv is empty")

    if not mr.empty:
        if "status" in mr.columns and (mr["status"] != "ok").any():
            bad = int((mr["status"] != "ok").sum())
            failures.append(f"non-ok model rows: {bad}")

        if "metric_value" in mr.columns and "status" in mr.columns:
            null_ok = mr[(mr["status"] == "ok") & (mr["metric_value"].isna())]
            if len(null_ok) > 0:
                failures.append(f"null metric_value on ok rows: {len(null_ok)}")

        if "metric_value" in mr.columns:
            non_finite = mr["metric_value"].map(_is_finite_or_na).eq(False).sum()
            if int(non_finite) > 0:
                failures.append(f"non-finite metric_value rows: {int(non_finite)}")

        if {"run_id"}.issubset(set(mr.columns)):
            dup = int(mr["run_id"].duplicated().sum())
            if dup > 0:
                failures.append(f"duplicate model run_id rows: {dup}")

    if not pw.empty:
        needed = {"difference_value", "ensemble_better"}
        if needed.issubset(set(pw.columns)):
            bad_sign = pw[
                ((pw["difference_value"] > 0) & (pw["ensemble_better"] != True))
                | ((pw["difference_value"] < 0) & (pw["ensemble_better"] != False))
                | ((pw["difference_value"] == 0) & (pw["ensemble_better"] != False))
            ]
            if len(bad_sign) > 0:
                failures.append(f"pairwise sign mismatch rows: {len(bad_sign)}")

        if {"comparison_id"}.issubset(set(pw.columns)):
            dup = int(pw["comparison_id"].duplicated().sum())
            if dup > 0:
                failures.append(f"duplicate comparison_id rows: {dup}")

    mr_samples: list[dict[str, Any]] = []
    pw_samples: list[dict[str, Any]] = []
    if not mr.empty:
        for i in _sample_positions(len(mr)):
            row = mr.iloc[i]
            mr_samples.append(
                {
                    "idx": int(i),
                    "metric_name": str(row.get("metric_name")),
                    "metric_value": None if pd.isna(row.get("metric_value")) else float(row.get("metric_value")),
                    "model_name": str(row.get("model_name")),
                    "fold": int(row.get("fold", 0)),
                    "repeat_id": int(row.get("repeat_id", 0)),
                    "train_time_sec": float(row.get("train_time_sec", 0.0)),
                    "predict_time_sec": float(row.get("predict_time_sec", 0.0)),
                }
            )
    if not pw.empty:
        for i in _sample_positions(len(pw)):
            row = pw.iloc[i]
            pw_samples.append(
                {
                    "idx": int(i),
                    "metric_name": str(row.get("metric_name")),
                    "single_metric_value": float(row.get("single_metric_value", 0.0)),
                    "ensemble_metric_value": float(row.get("ensemble_metric_value", 0.0)),
                    "difference_value": float(row.get("difference_value", 0.0)),
                    "ensemble_better": bool(row.get("ensemble_better", False)),
                }
            )

    if not mr.empty and "train_time_sec" in mr.columns:
        p95 = float(mr["train_time_sec"].quantile(0.95))
        p50 = float(mr["train_time_sec"].quantile(0.50))
        if p95 > 10 * max(p50, 1e-9):
            warnings.append(f"train_time_sec p95 ({p95:.4f}) is >10x p50 ({p50:.4f})")

    return {
        "task_type": task_name,
        "dataset_id": dataset_id,
        "single_model": single_model,
        "ensemble_model": ensemble_model,
        "run_dir": run_dir,
        "model_rows": int(len(mr)),
        "pairwise_rows": int(len(pw)),
        "failed_rows": int(len(failed)),
        "ok": len(failures) == 0,
        "failures": failures,
        "warnings": warnings,
        "model_samples": mr_samples,
        "pairwise_samples": pw_samples,
    }


def latest_run_dir(output_root: str, before: set[str]) -> str:
    dirs = [d for d in os.listdir(output_root) if os.path.isdir(os.path.join(output_root, d))]
    created = [d for d in dirs if d not in before]
    if len(created) != 1:
        # Fallback to newest
        created = sorted(dirs)
        if not created:
            raise RuntimeError(f"No run directory found under {output_root}")
        return os.path.join(output_root, created[-1])
    return os.path.join(output_root, created[0])


def run_one_unit(
    unit: Unit,
    base_cfg: dict[str, Any],
    near_profile: str,
    output_root: str,
    timeout_seconds: int,
) -> dict[str, Any]:
    os.makedirs(output_root, exist_ok=True)
    before = set(d for d in os.listdir(output_root) if os.path.isdir(os.path.join(output_root, d)))
    scoped_cfg = make_scoped_config(base_cfg, unit, near_profile, timeout_seconds)
    with tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False) as tf:
        yaml.safe_dump(scoped_cfg, tf, sort_keys=False)
        tmp_cfg_path = tf.name
    try:
        cmd = [
            sys.executable,
            "-m",
            "code.python.tpsm.main",
            "--config",
            tmp_cfg_path,
            "--output-dir",
            output_root,
            "--workers",
            "1",
            "--timeout",
            str(timeout_seconds),
        ]
        proc = subprocess.run(cmd, check=False, capture_output=True, text=True)
        run_dir = latest_run_dir(output_root, before)
        audit = audit_run(run_dir, unit.task_name, unit.dataset_id, unit.single_model, unit.ensemble_model)
        audit["command_exit_code"] = int(proc.returncode)
        audit["stdout_tail"] = "\n".join(proc.stdout.splitlines()[-12:])
        audit["stderr_tail"] = "\n".join(proc.stderr.splitlines()[-12:])
        if proc.returncode != 0:
            audit["ok"] = False
            audit["failures"] = list(audit.get("failures", [])) + [f"runner exit code {proc.returncode}"]
        return audit
    finally:
        try:
            os.remove(tmp_cfg_path)
        except OSError:
            pass


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Scoped near-production audit runner")
    p.add_argument("--base-config", default="config/production/datasets.yaml")
    p.add_argument("--output-root", default="outputs/active/py_scoped_audits")
    p.add_argument("--report-name", default="audit_summary")
    p.add_argument(
        "--near-profile",
        default="k10r3_ts10",
        choices=["k10r3_ts10", "k10r3_ts3", "k10r2_ts8", "k8r3_ts10"],
    )
    p.add_argument("--timeout-seconds", type=int, default=600)
    p.add_argument("--tasks", nargs="*", choices=["classification", "regression", "timeseries"])
    p.add_argument("--datasets", nargs="*", help="Optional dataset id filter")
    p.add_argument("--max-units", type=int, default=0, help="0 means no limit")
    p.add_argument("--clean-output-root", action="store_true")
    return p.parse_args()


def main() -> int:
    args = parse_args()
    base_cfg = load_yaml(args.base_config)
    dataset_filter = set(args.datasets) if args.datasets else None
    units = build_units(base_cfg, args.tasks, dataset_filter)
    if args.max_units and args.max_units > 0:
        units = units[: args.max_units]

    if not units:
        print("No matching units found.")
        return 2

    if args.clean_output_root and os.path.exists(args.output_root):
        shutil.rmtree(args.output_root)
    os.makedirs(args.output_root, exist_ok=True)

    print(f"Planned units: {len(units)}")
    reports: list[dict[str, Any]] = []
    for i, unit in enumerate(units, start=1):
        print(
            f"[{i}/{len(units)}] task={unit.task_name} dataset={unit.dataset_id} "
            f"pair={unit.single_model} vs {unit.ensemble_model}"
        )
        rep = run_one_unit(
            unit=unit,
            base_cfg=base_cfg,
            near_profile=args.near_profile,
            output_root=args.output_root,
            timeout_seconds=args.timeout_seconds,
        )
        reports.append(rep)
        status = "OK" if rep["ok"] else "FAIL"
        print(f"    -> {status} model_rows={rep['model_rows']} pairwise_rows={rep['pairwise_rows']}")
        if rep["failures"]:
            for f in rep["failures"]:
                print(f"       failure: {f}")

    report_jsonl = os.path.join(args.output_root, f"{args.report_name}.jsonl")
    report_csv = os.path.join(args.output_root, f"{args.report_name}.csv")
    with open(report_jsonl, "w", encoding="utf-8") as f:
        for r in reports:
            f.write(json.dumps(r, ensure_ascii=True) + "\n")

    flat = []
    for r in reports:
        flat.append(
            {
                "task_type": r["task_type"],
                "dataset_id": r["dataset_id"],
                "single_model": r["single_model"],
                "ensemble_model": r["ensemble_model"],
                "ok": r["ok"],
                "model_rows": r["model_rows"],
                "pairwise_rows": r["pairwise_rows"],
                "failure_count": len(r.get("failures", [])),
                "warning_count": len(r.get("warnings", [])),
                "run_dir": r["run_dir"],
            }
        )
    pd.DataFrame(flat).to_csv(report_csv, index=False)

    total = len(reports)
    failed = sum(1 for r in reports if not r["ok"])
    print("\nSummary")
    print(f"  total_units: {total}")
    print(f"  failed_units: {failed}")
    print(f"  pass_units: {total - failed}")
    print(f"  report_csv: {report_csv}")
    print(f"  report_jsonl: {report_jsonl}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
