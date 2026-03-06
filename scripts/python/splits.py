"""TPSM Pipeline - Train/test split generation."""
import numpy as np
import warnings
from sklearn.model_selection import RepeatedKFold, RepeatedStratifiedKFold


def get_base_seed(dataset_id: str | None = None, base: int = 42) -> int:
    """Generate a deterministic seed from dataset ID."""
    if dataset_id:
        return base + sum(dataset_id.encode("utf-8")) % 100000
    return base


def make_split_seed(base_seed: int, repeat_id: int, fold: int) -> int:
    """Generate a deterministic seed for a specific split."""
    return base_seed + repeat_id * 1000 + fold


def make_repeated_kfold_splits(df, split_cfg: dict, target_col: str | None = None, dataset_id: str | None = None):
    """Generate repeated k-fold splits."""
    k = split_cfg.get("folds", 5)
    repeats = split_cfg.get("repeats", 1)
    base_seed = get_base_seed(dataset_id)

    n = len(df)
    splits = []

    k_used = k
    if target_col and target_col in df.columns:
        y = df[target_col]
        # Only use stratified splits for classification (categorical targets)
        if y.dtype == object or y.nunique() <= 20:
            try:
                # Guard against sparse classes: stratified KFold requires
                # each class count >= n_splits. Reduce k when needed.
                class_counts = y.value_counts(dropna=False)
                min_class_count = int(class_counts.min()) if len(class_counts) else 0
                effective_k = k
                if min_class_count > 0 and min_class_count < k:
                    effective_k = max(2, min_class_count)
                    warnings.warn(
                        f"Adjusted folds from {k} to {effective_k} for dataset '{dataset_id}' "
                        f"because minority class has only {min_class_count} samples."
                    )
                rkf = RepeatedStratifiedKFold(n_splits=k, n_repeats=repeats, random_state=base_seed)
                if effective_k != k:
                    rkf = RepeatedStratifiedKFold(
                        n_splits=effective_k, n_repeats=repeats, random_state=base_seed
                    )
                k_used = effective_k
                iterator = list(rkf.split(df, y))
                splits_ok = True
            except ValueError:
                splits_ok = False
        else:
            splits_ok = False

        if not splits_ok:
            rkf = RepeatedKFold(n_splits=k, n_repeats=repeats, random_state=base_seed)
            iterator = list(rkf.split(df))
            k_used = k
    else:
        rkf = RepeatedKFold(n_splits=k, n_repeats=repeats, random_state=base_seed)
        iterator = list(rkf.split(df))
        k_used = k

    fold_counter = 0
    for train_idx, test_idx in iterator:
        repeat_id = fold_counter // k_used + 1
        fold = fold_counter % k_used + 1
        splits.append({
            "train_idx": train_idx.tolist(),
            "test_idx": test_idx.tolist(),
            "fold": fold,
            "repeat_id": repeat_id,
            "n_folds": k_used,
            "split_method": "repeated_kfold",
        })
        fold_counter += 1

    return splits


def make_rolling_origin_splits(df, split_cfg: dict, dataset_id: str | None = None):
    """Generate rolling origin (expanding window) splits for timeseries."""
    n_splits = split_cfg.get("splits", 5)
    n = len(df)
    min_train = max(50, n // (n_splits + 1))
    test_size = max(10, n // (n_splits + 2))

    splits = []
    for i in range(n_splits):
        train_end = min_train + i * test_size
        test_end = min(train_end + test_size, n)
        if train_end >= n or test_end > n:
            break
        splits.append({
            "train_idx": list(range(train_end)),
            "test_idx": list(range(train_end, test_end)),
            "fold": i + 1,
            "repeat_id": 1,
            "n_folds": n_splits,
            "split_method": "rolling_origin",
        })

    return splits


def make_splits(task_name: str, df, split_cfg: dict, target_col: str | None = None, dataset_id: str | None = None):
    """Generate train/test splits based on task type and config."""
    method = split_cfg.get("method", "repeated_kfold")
    if method == "rolling_origin" or task_name == "timeseries":
        return make_rolling_origin_splits(df, split_cfg, dataset_id)
    else:
        return make_repeated_kfold_splits(df, split_cfg, target_col, dataset_id)
