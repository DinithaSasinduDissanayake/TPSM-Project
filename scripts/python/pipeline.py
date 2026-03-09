"""TPSM Pipeline - Core pipeline execution (dataset task runner + pairwise builder)."""
import time
import traceback
import warnings
import numpy as np
import pandas as pd
from typing import Optional

from .data_loader import load_dataset
from .config import validate_dataset
from .splits import make_splits
from .models import run_model
from .metrics import calc_metrics, is_higher_better


# =============================================================================
# Preprocessing
# =============================================================================

def _is_string_col(series):
    """Check if a column is string/categorical (pandas 2.x and 3.x compatible)."""
    return (
        pd.api.types.is_string_dtype(series)
        or pd.api.types.is_categorical_dtype(series)
        or series.dtype == object
        or series.dtype.name == "category"
    )


def preprocess_for_modeling(df, target, task_name, ds_cfg):
    """
    Lightweight preprocessing before split generation.
    Returns the processed dataframe.
    """
    df = df.copy()

    # Force binary classification if configured
    if task_name == "classification" and ds_cfg.get("force_binary"):
        threshold = ds_cfg.get("binary_threshold")
        pos_vals = ds_cfg.get("binary_positive_vals")
        if threshold is not None:
            df[target] = (pd.to_numeric(df[target], errors="coerce") > threshold).astype(int)
        elif pos_vals:
            df[target] = df[target].astype(str).str.strip().isin([str(v).strip() for v in pos_vals]).astype(int)

    # Encode target for classification (before features, so we know the dtype)
    if task_name == "classification" and _is_string_col(df[target]):
        from sklearn.preprocessing import LabelEncoder
        le = LabelEncoder()
        df[target] = le.fit_transform(df[target].astype(str))

    # Drop rows where target is NaN
    df = df.dropna(subset=[target])

    return df


def preprocess_train_test_for_modeling(train_df, test_df, target, task_name, ds_cfg):
    """Leakage-safe split preprocessing using train-only statistics."""
    train_df = train_df.copy()
    test_df = test_df.copy()

    def _target_already_binary(series):
        vals = pd.Series(series).dropna().unique().tolist()
        return len(vals) <= 2 and set(vals).issubset({0, 1, 0.0, 1.0, False, True})

    # Force binary target if configured
    if task_name == "classification" and ds_cfg.get("force_binary") and not _target_already_binary(train_df[target]):
        threshold = ds_cfg.get("binary_threshold")
        pos_vals = ds_cfg.get("binary_positive_vals")
        if threshold is not None:
            train_df[target] = (pd.to_numeric(train_df[target], errors="coerce") > threshold).astype(int)
            test_df[target] = (pd.to_numeric(test_df[target], errors="coerce") > threshold).astype(int)
        elif pos_vals:
            norm_pos = [str(v).strip() for v in pos_vals]
            train_df[target] = train_df[target].astype(str).str.strip().isin(norm_pos).astype(int)
            test_df[target] = test_df[target].astype(str).str.strip().isin(norm_pos).astype(int)

    # Encode classification target from train labels only
    if task_name == "classification":
        tr_tgt = train_df[target]
        te_tgt = test_df[target]
        if _is_string_col(tr_tgt) or _is_string_col(te_tgt):
            tr_vals = tr_tgt.astype(str).fillna("NA")
            te_vals = te_tgt.astype(str).fillna("NA")
            classes = pd.Index(pd.unique(tr_vals))
            mapping = {v: i for i, v in enumerate(classes)}
            train_df[target] = tr_vals.map(mapping).astype(int)
            # Unknown labels are mapped to -1; they will naturally hurt metrics if present.
            test_df[target] = te_vals.map(mapping).fillna(-1).astype(int)

    # Feature encoding from train categories only
    candidate_cols = [c for c in train_df.columns if c != target and c in test_df.columns]
    for col in candidate_cols:
        if _is_string_col(train_df[col]) or _is_string_col(test_df[col]):
            tr_vals = train_df[col].astype(str).fillna("NA")
            te_vals = test_df[col].astype(str).fillna("NA")

            # Skip expensive datetime parsing unless values look plausibly date-like.
            sample_vals = pd.concat([tr_vals.head(20), te_vals.head(20)], ignore_index=True)
            has_date_hint = bool(
                sample_vals.str.contains(r"\d", regex=True).mean() >= 0.8
                and sample_vals.str.contains(r"[-/:]", regex=True).mean() >= 0.5
            )

            # If a string column is date-like (e.g., monthly timestamps), use
            # numeric epoch representation so unseen dates in test still carry signal.
            if has_date_hint:
                with warnings.catch_warnings():
                    warnings.simplefilter("ignore", UserWarning)
                    tr_dt = pd.to_datetime(train_df[col], errors="coerce", utc=True)
                    te_dt = pd.to_datetime(test_df[col], errors="coerce", utc=True)
                tr_dt_ok = float(tr_dt.notna().mean()) if len(tr_dt) else 0.0
                te_dt_ok = float(te_dt.notna().mean()) if len(te_dt) else 0.0
                if tr_dt_ok >= 0.9 and te_dt_ok >= 0.9:
                    train_df[col] = (tr_dt.astype("int64") // 10**9).astype(float)
                    test_df[col] = (te_dt.astype("int64") // 10**9).astype(float)
                    continue

            classes = pd.Index(pd.unique(tr_vals))
            mapping = {v: i for i, v in enumerate(classes)}
            train_df[col] = tr_vals.map(mapping).astype(float)
            test_df[col] = te_vals.map(mapping).fillna(-1).astype(float)

    # Drop constant features based on train split only
    drop_cols = [c for c in candidate_cols if train_df[c].nunique(dropna=False) <= 1]
    if drop_cols:
        train_df = train_df.drop(columns=drop_cols)
        test_df = test_df.drop(columns=drop_cols, errors="ignore")

    # Median imputation from train split only
    num_cols = [c for c in train_df.columns if c != target and pd.api.types.is_numeric_dtype(train_df[c])]
    if num_cols:
        medians = train_df[num_cols].median(numeric_only=True)
        train_df[num_cols] = train_df[num_cols].fillna(medians)
        test_df[num_cols] = test_df[num_cols].fillna(medians)

    train_df = train_df.dropna(subset=[target]).reset_index(drop=True)
    test_df = test_df.dropna(subset=[target]).reset_index(drop=True)
    return train_df, test_df


# =============================================================================
# Pairwise Comparison Builder
# =============================================================================

def _detect_positive_class(y, ds_cfg):
    """Detect the positive class for binary classification."""
    pos = ds_cfg.get("positive_class")
    if pos is not None:
        return pos
    vals = sorted(y.unique())
    if len(vals) == 2:
        return vals[1]  # Higher value = positive
    return vals[0]


def build_pairwise_rows(model_pair, metric_results, split_info, ds_cfg, task_name, requested_metrics=None, run_id=""):
    """
    Build pairwise comparison rows for a model pair.
    Returns a list of dicts, one per requested metric.
    """
    single_name = model_pair["single"]
    ensemble_name = model_pair["ensemble"]

    rows = []
    single_metrics = metric_results.get(single_name, {})
    ensemble_metrics = metric_results.get(ensemble_name, {})
    
    metrics_to_compare = requested_metrics if requested_metrics else list(single_metrics.keys())
    
    for metric_name in metrics_to_compare:
        single_val = single_metrics.get(metric_name, np.nan)
        ensemble_val = ensemble_metrics.get(metric_name, np.nan)
        if pd.isna(single_val) or pd.isna(ensemble_val):
            continue

        higher_better = is_higher_better(metric_name)
        # R convention: positive diff always means ensemble is better
        if higher_better:
            diff = ensemble_val - single_val  # positive = ensemble better
            diff_def = f"ensemble_minus_single_{metric_name}"
        else:
            diff = single_val - ensemble_val  # positive = ensemble better (lower is better)
            diff_def = f"single_minus_ensemble_{metric_name}"
        ensemble_better = diff > 0

        cmp_id = f"cmp::{run_id}::{task_name}::{ds_cfg['id']}::{single_name}::{ensemble_name}::{split_info['fold']}::{split_info['repeat_id']}::{metric_name}"

        rows.append({
            "comparison_id": cmp_id,
            "run_id": run_id,
            "task_type": task_name,
            "dataset_id": ds_cfg["id"],
            "split_method": split_info["split_method"],
            "fold": split_info["fold"],
            "repeat_id": split_info["repeat_id"],
            "metric_name": metric_name,
            "single_model_name": single_name,
            "ensemble_model_name": ensemble_name,
            "single_metric_value": round(single_val, 6),
            "ensemble_metric_value": round(ensemble_val, 6),
            "difference_definition": diff_def,
            "difference_value": round(diff, 6),
            "ensemble_better": ensemble_better,
            "valid_pair": True,
            "notes": split_info.get("metric_notes", {}).get(metric_name),
        })

    return rows


# =============================================================================
# Core Pipeline
# =============================================================================

def evaluate_models_on_split(task_name, model_names, train_df, test_df, target,
                             ds_cfg, split_info, requested_metrics, run_id=""):
    """Evaluate all models on a single train/test split. Returns model_rows and metric_results."""
    model_rows = []
    metric_results = {}
    split_warnings = []

    # Determine model_family from model_pairs config
    model_family_map = {}
    for pair in ds_cfg.get("_model_pairs", []):
        model_family_map[pair["single"]] = "single"
        model_family_map[pair["ensemble"]] = "ensemble"

    for model_name in model_names:
        family = model_family_map.get(model_name, "single")
        ts_utc = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

        try:
            with warnings.catch_warnings(record=True) as caught:
                warnings.simplefilter("always")

                t_train = time.time()
                result = run_model(task_name, model_name, train_df, test_df, target, ds_cfg)
                train_sec = time.time() - t_train

                t_predict = time.time()
                metrics = calc_metrics(task_name, result["y_true"], result["y_pred"], result.get("y_prob"))
                predict_sec = time.time() - t_predict

                for w in caught:
                    split_warnings.append(str(w.message))

            metric_results[model_name] = metrics

            for metric_name in requested_metrics:
                val = metrics.get(metric_name, np.nan)
                row_id = f"run::{run_id}::{task_name}::{ds_cfg['id']}::{model_name}::{split_info['fold']}::{split_info['repeat_id']}::{metric_name}"
                model_rows.append({
                    "run_id": row_id,
                    "task_type": task_name,
                    "dataset_id": ds_cfg["id"],
                    "dataset_source": ds_cfg.get("source", "unknown"),
                    "model_family": family,
                    "model_name": model_name,
                    "split_method": split_info["split_method"],
                    "fold": split_info["fold"],
                    "repeat_id": split_info["repeat_id"],
                    "n_folds": split_info["n_folds"],
                    "train_rows": len(train_df),
                    "test_rows": len(test_df),
                    "train_time_sec": round(train_sec, 6),
                    "predict_time_sec": round(predict_sec, 6),
                    "metric_name": metric_name,
                    "metric_value": round(float(val), 6) if not np.isnan(val) else None,
                    "timestamp_utc": ts_utc,
                    "status": "ok",
                    "error_message": None,
                })

        except Exception as e:
            split_warnings.append(f"{model_name}: {e}")
            for metric_name in requested_metrics:
                row_id = f"run::{run_id}::{task_name}::{ds_cfg['id']}::{model_name}::{split_info['fold']}::{split_info['repeat_id']}::{metric_name}"
                model_rows.append({
                    "run_id": row_id,
                    "task_type": task_name,
                    "dataset_id": ds_cfg["id"],
                    "dataset_source": ds_cfg.get("source", "unknown"),
                    "model_family": family,
                    "model_name": model_name,
                    "split_method": split_info["split_method"],
                    "fold": split_info["fold"],
                    "repeat_id": split_info["repeat_id"],
                    "n_folds": split_info["n_folds"],
                    "train_rows": len(train_df),
                    "test_rows": len(test_df),
                    "train_time_sec": None,
                    "predict_time_sec": None,
                    "metric_name": metric_name,
                    "metric_value": None,
                    "timestamp_utc": ts_utc,
                    "status": "error",
                    "error_message": str(e),
                })

    return model_rows, metric_results, split_warnings


def run_dataset_task(
    task,
    ds_cfg,
    log_fn,
    timeout_sec=300,
    run_id="",
    control_fn=None,
    completed_unit_ids=None,
    on_split_complete=None,
):
    """
    Run all models on all splits for a single dataset.
    Returns a result dict with model_runs, pairwise_rows, warnings, failed status.
    """
    result = {
        "dataset_id": ds_cfg["id"],
        "task_name": task["name"],
        "model_runs": [],
        "pairwise_rows": [],
        "warnings": [],
        "failed": False,
        "error_message": None,
        "elapsed_sec": 0,
        "stopped": False,
        "stop_reason": None,
    }

    start_time = time.time()

    try:
        # Load dataset
        log_fn("info", "dataset_start", {"task": task["name"], "dataset": ds_cfg["id"]})
        t0 = time.time()
        df = load_dataset(ds_cfg)
        load_sec = time.time() - t0
        log_fn("info", "dataset_loaded", {"dataset": ds_cfg["id"], "rows": len(df), "cols": len(df.columns)})
        if ds_cfg.get("_column_match_diagnostics", {}).get("renamed_columns"):
            log_fn("info", "dataset_column_match", {
                "dataset": ds_cfg["id"],
                "renamed_columns": ds_cfg["_column_match_diagnostics"]["renamed_columns"],
            })
        log_fn("debug", "dataset_stage_complete", {"task": task["name"], "dataset": ds_cfg["id"], "stage": "load", "elapsed_sec": round(load_sec, 4)})

        # Validate and preprocess
        t1 = time.time()
        validate_dataset(df, ds_cfg, task["name"], result["warnings"])
        df = preprocess_for_modeling(df, ds_cfg["target"], task["name"], ds_cfg)
        prep_sec = time.time() - t1
        log_fn("debug", "dataset_stage_complete", {"task": task["name"], "dataset": ds_cfg["id"], "stage": "prepare", "elapsed_sec": round(prep_sec, 4)})

        # Make splits
        t2 = time.time()
        split_cfg = dict(task["split"])
        if task["name"] == "timeseries" and ds_cfg.get("splits_override"):
            split_cfg["splits"] = ds_cfg["splits_override"]
        splits = make_splits(task["name"], df, split_cfg, ds_cfg["target"], ds_cfg["id"])
        split_sec = time.time() - t2
        log_fn("debug", "dataset_stage_complete", {"task": task["name"], "dataset": ds_cfg["id"], "stage": "split", "elapsed_sec": round(split_sec, 4), "n_splits": len(splits)})

        # Collect all model names from pairs
        model_names = set()
        for pair in task.get("model_pairs", []):
            model_names.add(pair["single"])
            model_names.add(pair["ensemble"])
        model_names = sorted(model_names)

        # Pass model_pairs through ds_cfg for family detection
        ds_cfg_with_pairs = {**ds_cfg, "_model_pairs": task.get("model_pairs", [])}

        # Evaluate on each split
        t3 = time.time()
        total_splits = len(splits)
        for split_idx, split_info in enumerate(splits, start=1):
            split_info = dict(split_info)
            split_info["split_index"] = split_idx
            unit_id = (
                f"{task['name']}::{ds_cfg['id']}::"
                f"r{split_info['repeat_id']}::f{split_info['fold']}::i{split_idx}"
            )
            if completed_unit_ids and unit_id in completed_unit_ids:
                continue
            if control_fn:
                action = control_fn()
                if action in ("pause", "stop"):
                    result["stopped"] = True
                    result["stop_reason"] = action
                    break
            split_start = time.time()
            train_raw = df.iloc[split_info["train_idx"]].reset_index(drop=True)
            test_raw = df.iloc[split_info["test_idx"]].reset_index(drop=True)
            train_df, test_df = preprocess_train_test_for_modeling(
                train_raw, test_raw, ds_cfg["target"], task["name"], ds_cfg
            )

            # MAPE becomes unstable with many low denominators; emit a warning for audit context.
            low_warn = None
            if task["name"] in ("regression", "timeseries"):
                y_true = pd.to_numeric(test_df[ds_cfg["target"]], errors="coerce")
                valid = y_true.notna()
                if valid.any():
                    low_pct = float((y_true[valid].abs() <= 10).mean() * 100.0)
                    if low_pct > 10.0:
                        low_warn = (
                            f"{ds_cfg['id']} split r{split_info['repeat_id']}f{split_info['fold']}: "
                            f"MAPE low-target risk ({low_pct:.1f}% <= 10)"
                        )
                        result["warnings"].append(low_warn)
                        metric_notes = split_info.setdefault("metric_notes", {})
                        metric_notes["mape"] = f"low_target_risk:{low_pct:.1f}%_<=10"
                        metric_notes["smape"] = f"low_target_context:{low_pct:.1f}%_<=10"

            split_warnings = []
            if task["name"] in ("regression", "timeseries") and low_warn:
                split_warnings.append(low_warn)
            rows, metric_results, split_warns = evaluate_models_on_split(
                task["name"], model_names, train_df, test_df,
                ds_cfg["target"], ds_cfg_with_pairs, split_info, task.get("metrics", []),
                run_id=run_id
            )
            result["model_runs"].extend(rows)
            result["warnings"].extend(split_warns)
            split_warnings.extend(split_warns)

            # Build pairwise comparisons
            pairwise_rows = []
            for pair in task.get("model_pairs", []):
                pair_rows = build_pairwise_rows(
                    pair, metric_results, split_info, ds_cfg, task["name"],
                    requested_metrics=task.get("metrics", []),
                    run_id=run_id
                )
                result["pairwise_rows"].extend(pair_rows)
                pairwise_rows.extend(pair_rows)

            split_elapsed = time.time() - split_start
            if on_split_complete:
                on_split_complete(
                    {
                        "unit_id": unit_id,
                        "task_name": task["name"],
                        "dataset_id": ds_cfg["id"],
                        "split_index": split_idx,
                        "total_splits": total_splits,
                        "fold": split_info["fold"],
                        "repeat_id": split_info["repeat_id"],
                        "elapsed_sec": round(split_elapsed, 4),
                    },
                    rows,
                    pairwise_rows,
                    split_warnings,
                )
            if (
                total_splits <= 10
                or split_idx == 1
                or split_idx == total_splits
                or split_idx % 5 == 0
            ):
                log_fn("debug", "split_complete", {
                    "task": task["name"],
                    "dataset": ds_cfg["id"],
                    "split_index": split_idx,
                    "total_splits": total_splits,
                    "repeat_id": split_info["repeat_id"],
                    "fold": split_info["fold"],
                    "elapsed_sec": round(split_elapsed, 4),
                    "train_rows": len(train_df),
                    "test_rows": len(test_df),
                })

        if result["stopped"]:
            result["elapsed_sec"] = time.time() - start_time
            log_fn("info", "dataset_interrupted", {
                "task": task["name"],
                "dataset": ds_cfg["id"],
                "elapsed_sec": round(result["elapsed_sec"], 4),
                "stop_reason": result["stop_reason"],
                "n_model_runs": len(result["model_runs"]),
                "n_pairwise_rows": len(result["pairwise_rows"]),
                "n_warnings": len(result["warnings"]),
            })
            return result

        eval_sec = time.time() - t3

        result["elapsed_sec"] = time.time() - start_time
        log_fn("info", "dataset_complete", {
            "task": task["name"],
            "dataset": ds_cfg["id"],
            "elapsed_sec": round(result["elapsed_sec"], 4),
            "load_sec": round(load_sec, 4),
            "prepare_sec": round(prep_sec, 4),
            "split_sec": round(split_sec, 4),
            "evaluate_sec": round(eval_sec, 4),
            "n_model_runs": len(result["model_runs"]),
            "n_pairwise_rows": len(result["pairwise_rows"]),
            "n_warnings": len(result["warnings"]),
            "failed": False,
        })

    except Exception as e:
        result["failed"] = True
        result["error_message"] = f"{e}"
        result["elapsed_sec"] = time.time() - start_time
        log_fn("error", "dataset_stage_failed", {
            "task": task["name"],
            "dataset": ds_cfg["id"],
            "stage": "unknown",
            "elapsed_sec": round(result["elapsed_sec"], 4),
            "error_message": str(e),
        })

    return result
