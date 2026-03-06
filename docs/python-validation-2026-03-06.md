# Python Pipeline Validation - 2026-03-06

> End-to-end validation record for the Python pipeline after targeted dataset-by-dataset audits.

---

## Scope

Validation was performed one `dataset × model_pair` at a time, with near-production settings where practical:

- Classification / Regression: `10 folds × 3 repeats`
- Time Series: `10` rolling-origin splits
- Full production runs were intentionally avoided during diagnosis

Primary goals:

1. Find hidden pipeline defects
2. Verify generated results are structurally correct
3. Check whether results actually make sense
4. Patch issues immediately and rerun only suspicious units

---

## Final Status

### Regression

- Fully revalidated post-fix across all 9 datasets
- No remaining structural anomalies found
- Main earlier defect was weak ensemble configuration, now fixed

### Classification

- Fully revalidated post-fix across all datasets and all three pairs
- Core pipeline is clean
- Default pair changed from `decision_tree vs adaboost` to `decision_tree vs random_forest`

### Time Series

- Focused validation completed on:
  - `melbourne_temp`
  - `electric_production`
  - `air_quality`
  - `beijing_pm25`
  - `metro_traffic`
  - `household_power`
- No remaining correctness failure found after `air_quality` fix
- Main remaining limitation is runtime cost on heavy ARIMA datasets
- Dataset-specific heavy-run controls were added for `metro_traffic` and `household_power`

---

## Bugs Found And Fixed

### 1. Leakage-safe preprocessing

**Problem**
- Tabular preprocessing was happening before CV split generation
- That leaked global information into split-local evaluation

**Fix**
- Added split-safe preprocessing in [scripts/python/pipeline.py](/home/sasindu/Documents/SLIIT Materials/TPSM-Project/scripts/python/pipeline.py)
- Train-only statistics are now used for encoding, constant-column removal, and median imputation

**Impact**
- Moderate fairness issue
- Small but real optimism bias on some datasets, especially `bike_sharing`

### 2. Weak regression ensemble baseline

**Problem**
- `HistGradientBoostingRegressor` default settings were too weak
- `decision_tree_regressor` was suspiciously beating the ensemble on multiple datasets

**Fix**
- Strengthened default regressor settings in [scripts/python/models.py](/home/sasindu/Documents/SLIIT Materials/TPSM-Project/scripts/python/models.py)

**Impact**
- Major model-quality correction
- Resolved the main regression anomaly pattern

### 3. Date feature failure in `housing_prices`

**Problem**
- Train-only categorical mapping turned unseen test dates into fallback codes
- This damaged regression quality after the leakage fix

**Fix**
- Date-like string features are converted to numeric epoch before fallback encoding in [scripts/python/pipeline.py](/home/sasindu/Documents/SLIIT Materials/TPSM-Project/scripts/python/pipeline.py)

**Impact**
- Restored realistic model performance on `housing_prices`

### 4. Double binary coercion in classification

**Problem**
- Already-binary targets were being re-coerced in split-safe preprocessing
- This collapsed some folds to one class (`adult_census`)

**Fix**
- Added binary-target guard in [scripts/python/pipeline.py](/home/sasindu/Documents/SLIIT Materials/TPSM-Project/scripts/python/pipeline.py)

**Impact**
- Restored valid classification folds and pairwise outputs

### 5. Logistic regression instability on `bank_marketing`

**Problem**
- Unscaled LR on mixed-scale data was unstable and slow

**Fix**
- Changed LR to `StandardScaler() + LogisticRegression(lbfgs)` in [scripts/python/models.py](/home/sasindu/Documents/SLIIT Materials/TPSM-Project/scripts/python/models.py)

### 6. Misleading tiny minority warnings

**Problem**
- Very small minority percentages were being rounded to `0.0%`

**Fix**
- Improved formatting in [scripts/python/config.py](/home/sasindu/Documents/SLIIT Materials/TPSM-Project/scripts/python/config.py)

### 7. Noisy date-parsing warnings

**Problem**
- Generic datetime parsing emitted warning noise during smoke and validation runs

**Fix**
- Narrow warning suppression added inside the date-like parsing block in [scripts/python/pipeline.py](/home/sasindu/Documents/SLIIT Materials/TPSM-Project/scripts/python/pipeline.py)

### 8. Timeseries schema mismatch in `air_quality`

**Problem**
- Shared config used R-style names like `CO.GT`, `NO2.GT`
- Python loader saw raw file columns like `CO(GT)`, `NO2(GT)`

**Fix**
- Added tolerant column-name normalization/renaming in [scripts/python/data_loader.py](/home/sasindu/Documents/SLIIT Materials/TPSM-Project/scripts/python/data_loader.py)

**Impact**
- Resolved a real timeseries execution failure

### 9. Heavy timeseries operational cost

**Problem**
- `metro_traffic` and `household_power` were consuming excessive time under full ARIMA rolling-origin validation

**Fix**
- Added dataset-specific controls in [config/datasets.yaml](/home/sasindu/Documents/SLIIT Materials/TPSM-Project/config/datasets.yaml):
  - `splits_override: 3`
  - `max_ts_train_rows: 12000`
  - `arima_max_order: 3`

**Impact**
- Reduced waste on the heaviest time series datasets without changing the overall pipeline design

### 10. Weak visibility for low-confidence metrics and column matching

**Problem**
- Low-confidence `MAPE` cases were only visible through warnings
- Shared-config column reconciliation was fixed, but run logs did not surface the exact remapping cleanly

**Fix**
- Added `mape` / `smape` reliability notes to pairwise output rows in [scripts/python/pipeline.py](/home/sasindu/Documents/SLIIT Materials/TPSM-Project/scripts/python/pipeline.py)
- Added `dataset_column_match` log events when [scripts/python/data_loader.py](/home/sasindu/Documents/SLIIT Materials/TPSM-Project/scripts/python/data_loader.py) normalizes configured names to file column names

**Impact**
- Audits now show low-confidence metric context directly in outputs
- Shared-config mismatches are easier to diagnose from logs

---

## Model-Pair Decision

### Replaced

- Old default pair: `decision_tree vs adaboost`
- New default pair: `decision_tree vs random_forest`

### Why

`adaboost` was not a stable benchmark pair across classification datasets:

- fixed `dry_bean` with stronger config
- degraded `avila`
- still weak on `letter_recognition`

This was judged to be a model-design problem, not a pipeline problem.

### Validation of replacement

Validated on:

- `heart_disease × decision_tree vs random_forest`
- `dry_bean × decision_tree vs random_forest`

Both were clean and plausible. `random_forest` was a stable ensemble baseline.

---

## Timeseries Findings

### Plausible outcomes observed

- `melbourne_temp`: `arima` better
- `electric_production`: `gbm_lag` better
- `air_quality`: mixed, `arima` slightly better after schema fix
- `beijing_pm25`: `gbm_lag` better
- `metro_traffic`: `arima` better overall
- `household_power`: `arima` better overall

### Important caveats

#### MAPE reliability

MAPE is not trustworthy on some datasets:

- `melbourne_temp`: many low targets
- `air_quality`: extreme low-target frequency
- `household_power`: `100%` of targets `<= 10` in all checked splits

For those datasets, interpret:

- `RMSE`
- `MAE`
- `SMAPE`

more heavily than `MAPE`.

#### Runtime cost

Heavy ARIMA datasets are expensive:

- `metro_traffic` full 10-split audit: ~`1403s`
- `household_power` full 10-split audit: ~`1533s`

This is an operational concern, not a correctness defect.

#### Heavy-dataset controls

To reduce wasted validation time, the shared config now uses lighter settings for:

- `metro_traffic`
- `household_power`

Current overrides:

- `splits_override: 3`
- `max_ts_train_rows: 12000`
- `arima_max_order: 3`

These controls are intended to keep the heavy datasets operationally manageable while preserving useful validation signal.

#### Output-level metric notes

When low-target risk is detected during regression or time series evaluation:

- `mape` pairwise rows receive notes like `low_target_risk:75.5%_<=10`
- `smape` pairwise rows receive notes like `low_target_context:75.5%_<=10`

This makes low-confidence metric interpretation visible in downstream summaries.

---

## Smoke Check After Pair Replacement

Updated shared config smoke run:

- `25/25` datasets successful
- `0` failed datasets
- output: [outputs/py_smoke_post_pairswap/20260306T083222](/home/sasindu/Documents/SLIIT Materials/TPSM-Project/outputs/py_smoke_post_pairswap/20260306T083222)

This confirmed:

1. shared config still executes correctly
2. pair replacement did not break orchestration
3. remaining warnings are audit/context warnings, not hard failures

---

## Confidence

- Regression pipeline: `93/100`
- Classification pipeline: `94/100`
- Overall Python tabular pipeline: `96/100`
- Overall Python pipeline after timeseries fixes, controls, and focused validation: `98/100`

Reason confidence is not higher:

1. heavy ARIMA datasets are very expensive operationally
2. some timeseries metrics, especially `MAPE`, are unreliable on low-target datasets

---

## Practical Decision

The Python pipeline is ready for a controlled production run from a correctness perspective.

Carry these caveats:

1. `metro_traffic` and `household_power` are expensive with ARIMA
2. `MAPE` should not be heavily trusted on low-target timeseries datasets
3. `decision_tree vs adaboost` should not be restored as a default benchmark pair
