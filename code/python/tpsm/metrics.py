"""TPSM Pipeline - Metric calculation."""

import numpy as np
from sklearn.metrics import (
    accuracy_score,
    precision_score,
    recall_score,
    f1_score,
    roc_auc_score,
    log_loss,
    mean_squared_error,
    mean_absolute_error,
    r2_score,
)
import warnings


def safe_div(a, b, default=0.0):
    """Safe division returning default on zero denominator."""
    return a / b if b != 0 else default


def calc_mape(y_true, y_pred):
    """Mean Absolute Percentage Error.

    Matches R: caps individual APE at 10 (1000%) before averaging,
    and filters out y_true values near zero.
    """
    y_true, y_pred = np.array(y_true, dtype=float), np.array(y_pred, dtype=float)
    mask = np.abs(y_true) > 1e-6
    if not mask.any():
        return np.nan
    ape = np.abs((y_true[mask] - y_pred[mask]) / y_true[mask])
    ape = np.minimum(ape, 10)  # R: pmin(mape_vals, 10)
    return np.mean(ape) * 100


def calc_smape(y_true, y_pred):
    """Symmetric Mean Absolute Percentage Error."""
    y_true, y_pred = np.array(y_true, dtype=float), np.array(y_pred, dtype=float)
    denom = np.abs(y_true) + np.abs(y_pred)
    mask = denom != 0
    if not mask.any():
        return np.nan
    return np.mean(2.0 * np.abs(y_true[mask] - y_pred[mask]) / denom[mask]) * 100


def calc_metrics(
    task_name: str, y_true, y_pred, y_prob=None, positive_class=None
) -> dict:
    """Calculate all relevant metrics for the given task type."""
    results = {}
    y_true = np.array(y_true)
    y_pred = np.array(y_pred)

    with warnings.catch_warnings():
        warnings.simplefilter("ignore")

        if task_name == "classification":
            results["accuracy"] = accuracy_score(y_true, y_pred)
            n_classes = len(np.unique(y_true))

            if n_classes == 2:
                unique_classes = np.unique(y_true)
                if positive_class is not None and positive_class in unique_classes:
                    pos_label = positive_class
                else:
                    pos_label = unique_classes[-1]
                results["precision"] = precision_score(
                    y_true,
                    y_pred,
                    average="binary",
                    pos_label=pos_label,
                    zero_division=0,
                )
                results["recall"] = recall_score(
                    y_true,
                    y_pred,
                    average="binary",
                    pos_label=pos_label,
                    zero_division=0,
                )
                results["f1"] = f1_score(
                    y_true,
                    y_pred,
                    average="binary",
                    pos_label=pos_label,
                    zero_division=0,
                )
            else:
                results["precision"] = precision_score(
                    y_true, y_pred, average="macro", zero_division=0
                )
                results["recall"] = recall_score(
                    y_true, y_pred, average="macro", zero_division=0
                )
                results["f1"] = f1_score(
                    y_true, y_pred, average="macro", zero_division=0
                )

            if y_prob is not None:
                try:
                    if n_classes == 2:
                        unique_classes = np.unique(y_true)
                        if (
                            positive_class is not None
                            and positive_class in unique_classes
                        ):
                            pos_label = positive_class
                        else:
                            pos_label = unique_classes[-1]
                        prob = np.array(y_prob, dtype=float)
                        y_bin = (y_true == pos_label).astype(float)
                        results["roc_auc"] = roc_auc_score(y_bin, prob)
                        prob_clipped = np.clip(prob, 1e-15, 1 - 1e-15)
                        results["logloss"] = log_loss(y_bin, prob_clipped)
                    else:
                        results["roc_auc"] = roc_auc_score(
                            y_true, y_prob, multi_class="ovr", average="weighted"
                        )
                        results["logloss"] = log_loss(y_true, y_prob)
                except Exception:
                    results["roc_auc"] = np.nan
                    results["logloss"] = np.nan
            else:
                results["roc_auc"] = np.nan
                results["logloss"] = np.nan

        elif task_name == "regression":
            results["rmse"] = np.sqrt(mean_squared_error(y_true, y_pred))
            results["mae"] = mean_absolute_error(y_true, y_pred)
            results["r2"] = r2_score(y_true, y_pred)
            results["mape"] = calc_mape(y_true, y_pred)

        elif task_name == "timeseries":
            results["rmse"] = np.sqrt(mean_squared_error(y_true, y_pred))
            results["mae"] = mean_absolute_error(y_true, y_pred)
            results["mape"] = calc_mape(y_true, y_pred)
            results["smape"] = calc_smape(y_true, y_pred)

    return results


HIGHER_IS_BETTER = {"accuracy", "precision", "recall", "f1", "roc_auc", "r2"}


def is_higher_better(metric_name: str) -> bool:
    """Return True if higher values of this metric are better."""
    return metric_name in HIGHER_IS_BETTER
