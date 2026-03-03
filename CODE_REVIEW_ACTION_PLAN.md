# TPSM Pipeline - Action Plan
# Based on Code Review (T3 Chat, 3 March 2026)
# Generated: 2026-03-03T14:30:45+05:30

---

## Executive Summary

- **Total Issues Identified:** 28
- **Valid Issues:** 18 (64%)
- **Partially Valid / Low-Risk:** 6 (21%)
- **Invalid / Overstated:** 4 (14%)

**Critical Priority:** Fix C1 and C2 immediately - these invalidate time series results.
**High Priority:** Fix robustness issues to prevent cryptic crashes.
**Medium Priority:** Code quality and maintenance improvements.
**Low Priority:** Style and optimization refinements.

---

## Priority Tier 1: CRITICAL (Fix Immediately)

### 1.1 Fix Time Series Data Leakage (C1)
**Confidence:** 95% | **Severity:** 🔴 Critical | **Impact:** Invalidates 100% TS win rate

**Problem:** GBM lag model uses `full_y = c(y_train, y_test)` to build lag features. Test observations beyond the first step use actual test values as lag features, creating an unfair comparison with ARIMA/exp_smoothing which forecast blind.

**Evidence:** models_timeseries.R:86-92; results.md shows 100% TS ensemble win rate (suspiciously perfect).

**Impact:** Systematic inflation of GBM performance. The entire time series conclusion is invalid.

**Recommended Fix:** Implement recursive forecasting for GBM:

```r
# Replace train_predict_timeseries gbm_lag branch with:
if (model_name == "gbm_lag") {
  if (!requireNamespace("gbm", quietly = TRUE)) stop("Package 'gbm' required")

  # Build lag matrix ONLY from training data
  lag_df_train <- make_lag_matrix(y_train, max_lag = lag, exog = exog_train, exog_max_lag = 6)
  lag_df_train <- na.omit(lag_df_train)

  # Ensure enough training data
  min_train_rows <- max(30, lag * 2)
  if (nrow(lag_df_train) < min_train_rows) {
    stop(sprintf("Not enough training data for lagged model: %d rows (need >= %d)",
                 nrow(lag_df_train), min_train_rows))
  }

  # Fit model on training lags
  x_train <- as.matrix(lag_df_train[, setdiff(names(lag_df_train), "target"), drop = FALSE])
  y_train_lag <- lag_df_train$target
  train_lag_df <- data.frame(target = y_train_lag, x_train)

  col_names <- c("target", paste0("x", seq_len(ncol(x_train))))
  names(train_lag_df) <- col_names

  fit <- gbm::gbm(target ~ ., data = train_lag_df, distribution = "gaussian",
                   n.trees = 100, interaction.depth = 3, shrinkage = 0.05,
                   n.minobsinnode = 10, verbose = FALSE)

  # Recursive forecasting - predict one step at a time
  preds <- numeric(length(y_test))
  current_y <- y_train

  for (i in seq_along(y_test)) {
    # Build lag matrix from current history (train + previous predictions)
    current_exog <- if (!is.null(exog_test)) exog_test[i, , drop = FALSE] else NULL
    lag_df_step <- make_lag_matrix(c(current_y, y_test[i]), max_lag = lag, exog = current_exog, exog_max_lag = 6)
    lag_df_step <- na.omit(lag_df_step)

    # Get features for prediction (last row)
    x_step <- as.matrix(lag_df_step[nrow(lag_df_step), setdiff(names(lag_df_step), "target"), drop = FALSE])
    test_lag_df <- data.frame(x_step)
    names(test_lag_df) <- paste0("x", seq_len(ncol(x_step)))

    # Predict
    preds[i] <- gbm::predict(fit, newdata = test_lag_df, n.trees = 100)

    # Update history with prediction (use prediction for next lag)
    current_y <- c(current_y, preds[i])
  }

  return(as.numeric(preds))
}
```

**Files to Modify:**
- `scripts/R/models_timeseries.R` (lines 86-120)

**Testing Required:**
- Re-run time series experiments
- Verify ensemble win rate drops from 100% to realistic levels
- Compare metrics to ensure no other regressions

**Estimated Effort:** 2-3 hours

---

### 1.2 Fix Exogenous Variable Inequality (C2)
**Confidence:** 90% | **Severity:** 🔴 Critical | **Impact:** Unfair feature access for 4/6 TS datasets

**Problem:** GBM lag uses exogenous columns as lag features, but ARIMA and exp_smoothing ignore them. For air_quality, beijing_pm25, metro_traffic, and household_power (4 of 6 datasets), GBM has access to additional predictive information.

**Evidence:** models_timeseries.R:86-90 (GBM uses exog); lines 43-62 (ARIMA/exp_smoothing ignore exog); config shows 4 datasets with exog_cols.

**Impact:** Second systematic advantage stacked on top of C1. Compounds fairness issue.

**Recommended Fix:** Two options:

**Option A (Recommended):** Add ARIMAX support via `forecast` package:

```r
# Add to train_predict_timeseries arima branch:
if (model_name == "arima") {
  # ... existing grid search code ...

  if (!is.null(exog_train) && !is.null(exog_test) && requireNamespace("forecast", quietly = TRUE)) {
    # ARIMAX - ARIMA with exogenous regressors
    # Need to align exog with training size after differencing
    fit <- forecast::Arima(y_train, order = best_order, xreg = exog_train)
    fc <- forecast::forecast(fit, h = length(y_test), xreg = exog_test)$mean
  } else {
    # Standard ARIMA (no exog support)
    fit <- stats::arima(y_train, order = best_order, method = "ML")
    fc <- stats::predict(fit, n.ahead = length(y_test))$pred
  }
  return(as.numeric(fc))
}
```

**Option B (Fallback):** Remove exog from GBM to ensure equal comparison:

```r
# In train_predict_timeseries gbm_lag branch, force exog = NULL:
lag_df <- make_lag_matrix(full_y, max_lag = lag, exog = NULL, exog_max_lag = 6)
```

**Option C (Document Only):** Document this as a known limitation in methodology.

**Recommendation:** Implement Option A for fair comparison, or Option B if ARIMAX is too complex for the project scope.

**Files to Modify:**
- `scripts/R/models_timeseries.R` (lines 42-62)

**Testing Required:**
- Re-run time series experiments
- Compare ARIMA performance with/without exog
- Verify fair comparison with GBM

**Estimated Effort:** 1-2 hours (Option A), 5 minutes (Option B)

---

## Priority Tier 2: HIGH (Fix Before Next Production Run)

### 2.1 Add Empty Feature Matrix Guard (H4)
**Confidence:** 75% | **Severity:** 🟠 High | **Impact:** Cryptic crashes

**Problem:** After zero-variance removal in preprocess_split(), no check if any features remain. If all features are removed, models crash with unhelpful errors.

**Evidence:** pairwise_builder.R:226-233 (zero-variance removal without guard)

**Recommended Fix:**

```r
# Add after zero-variance removal block (line 233):
feature_cols <- setdiff(names(train_df), ds_cfg$target)
if (length(feature_cols) == 0) {
  stop(sprintf(
    "No features remaining after preprocessing for dataset '%s'. " +
    "All columns were removed (zero variance, ID columns, excluded columns).",
    ds_cfg$id
  ))
}
```

**Files to Modify:**
- `scripts/R/pairwise_builder.R` (insert after line 233)

**Testing Required:**
- Test with a dataset that would result in zero features
- Verify clear error message

**Estimated Effort:** 15 minutes

---

### 2.2 Add Empty Test Set Guard (H6)
**Confidence:** 80% | **Severity:** 🟠 High | **Impact:** Cryptic crashes

**Problem:** After removing rows with NA targets, no check if test/train sets are empty. All downstream operations crash.

**Evidence:** pairwise_builder.R:212-213 (NA removal without guard)

**Recommended Fix:**

```r
# Replace lines 212-213 with:
train_df <- train_df[!is.na(train_df[[ds_cfg$target]]), , drop = FALSE]
test_df  <- test_df[!is.na(test_df[[ds_cfg$target]]), , drop = FALSE]

# Add validation:
if (nrow(train_df) == 0) {
  stop(sprintf(
    "Train set empty after NA target removal for dataset '%s'",
    ds_cfg$id
  ))
}
if (nrow(test_df) == 0) {
  stop(sprintf(
    "Test set empty after NA target removal for dataset '%s'. " +
    "Fold %d, repeat %d may have all NA targets.",
    ds_cfg$id, split$fold, split$repeat_id
  ))
}
```

**Files to Modify:**
- `scripts/R/pairwise_builder.R` (lines 212-213)

**Testing Required:**
- Test with dataset that has NA targets
- Verify clear error on empty set

**Estimated Effort:** 15 minutes

---

### 2.3 Deduplicate Positive Class Warning (H7)
**Confidence:** 90% | **Severity:** 🟠 High | **Impact:** Warning flood

**Problem:** Warning fires for every split (50 times per dataset for 10-fold × 5 repeats). Floods warnings_report.json.

**Evidence:** pairwise_builder.R:68-71; other runs show 50+ identical warnings

**Recommended Fix:** Cache positive class decision in dataset config:

```r
# In prepare_target_for_split() - move warning to only fire once per dataset:
# Option 1: Add caching via ds_cfg
if (!is.null(ds_cfg$positive_class)) {
  positive_val <- ds_cfg$positive_class
} else {
  unique_vals <- sort(unique(as.character(y_train)))
  if (length(unique_vals) != 2) {
    stop(sprintf("Expected 2 classes in training data, got %d", length(unique_vals)))
  }
  positive_val <- unique_vals[2]

  # Only warn if not already cached
  if (is.null(ds_cfg$positive_class_cached)) {
    warning(sprintf(
      "No positive class specified for '%s', using '%s' (alphabetically second). " +
      "Consider setting positive_class in config to suppress this warning.",
      ds_cfg$id, positive_val
    ))
    ds_cfg$positive_class_cached <- positive_val  # Cache it
  }
}

# Option 2: Use a global cache with warning.once()
warning.once <- function(...) {
  warning(sprintf("No positive class specified for '%s', using '%s'. " +
                  "Consider setting positive_class in config.", ds_cfg$id, positive_val),
          call. = FALSE, immediate. = TRUE)
}
# Then call warning.once() only if not yet called for this dataset
```

**Recommendation:** Option 1 is cleaner - cache in ds_cfg.

**Files to Modify:**
- `scripts/R/pairwise_builder.R` (lines 64-71)

**Testing Required:**
- Run pipeline and verify only 1 warning per dataset (not 50)

**Estimated Effort:** 30 minutes

---

### 2.4 Fix `plan(sequential)` Check (M3)
**Confidence:** 85% | **Severity:** 🟠 High | **Impact:** Logic error

**Problem:** `exists("plan")` checks if the function exists (always true after loading future), not if parallel mode was active.

**Evidence:** main.R:111

**Recommended Fix:**

```r
# Replace line 111-113 with:
if (parallel_workers > 1 && future_available) {
  plan(sequential)
  log_event(run_ctx, "info", "parallel_disabled", list(reason = "run_complete"))
}
```

**Files to Modify:**
- `scripts/main.R` (lines 111-113)

**Testing Required:**
- Run in parallel mode, verify plan resets correctly
- Check log file for "parallel_disabled" event

**Estimated Effort:** 10 minutes

---

### 2.5 Add ARIMA Grid Search Warning (M5)
**Confidence:** 90% | **Severity:** 🟠 High | **Impact:** Silent failures

**Problem:** If all 18 ARIMA orders fail silently, code falls through to use (1,1,1) which may also fail. No indication of failure.

**Evidence:** models_timeseries.R:46-58 (silent error swallowing)

**Recommended Fix:**

```r
# Add after line 58 (after grid search loop):
if (best_aic == Inf) {
  warning(sprintf(
    "All ARIMA orders failed during grid search for dataset. " +
    "Falling back to default order (1,1,1). This may indicate non-stationary data or numerical issues."
  ))
}
```

**Files to Modify:**
- `scripts/R/models_timeseries.R` (insert after line 58)

**Testing Required:**
- Test with problematic time series data
- Verify warning appears when all orders fail

**Estimated Effort:** 10 minutes

---

## Priority Tier 3: MEDIUM (Code Quality & Robustness)

### 3.1 Fix `ifelse()` Scalar Logic (M7)
**Confidence:** 95% | **Severity:** 🟡 Medium | **Impact:** Inefficiency

**Problem:** `ifelse()` evaluates both branches even for scalars. Less efficient than `if...else`.

**Evidence:** metrics.R:29, 66

**Recommended Fix:**

```r
# Replace line 29 with:
if (is.na(precision) || is.na(recall) || (precision + recall) == 0) {
  f1 <- NA_real_
} else {
  f1 <- 2 * precision * recall / (precision + recall)
}

# Replace line 66 with:
if (is.na(precisions[i + 1]) || is.na(recalls[i + 1]) ||
    (precisions[i + 1] + recalls[i + 1]) == 0) {
  f1s[i + 1] <- NA_real_
} else {
  f1s[i + 1] <- 2 * precisions[i + 1] * recalls[i + 1] /
                (precisions[i + 1] + recalls[i + 1])
}
```

**Files to Modify:**
- `scripts/R/metrics.R` (lines 29, 66)

**Estimated Effort:** 10 minutes

---

### 3.2 Log Multiclass AUC Failures (M8)
**Confidence:** 70% | **Severity:** 🟡 Medium | **Impact:** Silent debugging difficulty

**Problem:** When multiclass AUC calculation fails, error is swallowed silently and returns NA without logging why.

**Evidence:** metrics.R:86-89

**Recommended Fix:**

```r
# Replace lines 86-89 with:
tryCatch({
  roc_obj <- pROC::multiclass.roc(factor(y_true_int), y_prob, quiet = TRUE)
  out$roc_auc <- as.numeric(pROC::auc(roc_obj))
}, error = function(e) {
  warning(sprintf("Multiclass AUC calculation failed: %s. " +
                  "Setting AUC to NA.", e$message))
  out$roc_auc <- NA_real_
})
```

**Files to Modify:**
- `scripts/R/metrics.R` (lines 86-89)

**Estimated Effort:** 10 minutes

---

### 3.3 Add Column Removal Logging (M9)
**Confidence:** 85% | **Severity:** 🟡 Medium | **Impact:** No audit trail

**Problem:** ID columns, excluded columns, time columns, zero-variance columns removed silently. No audit trail.

**Evidence:** pairwise_builder.R:193, 229-231

**Recommended Fix:**

```r
# After each removal block, log what was removed:

# After line 197 (all drop_cols determined):
if (length(drop_cols) > 0) {
  log_event(run_ctx, "info", "columns_removed",
             list(dataset = ds_cfg$id, columns = drop_cols, reason = "excluded/id/time"))
}

# After line 233 (zero-variance removal):
if (any(zero_var)) {
  drop <- names(which(zero_var))
  log_event(run_ctx, "info", "zero_variance_columns_removed",
             list(dataset = ds_cfg$id, columns = drop))
  train_df <- train_df[, setdiff(names(train_df), drop), drop = FALSE]
  test_df <- test_df[, setdiff(names(test_df), drop), drop = FALSE]
}
```

**Files to Modify:**
- `scripts/R/pairwise_builder.R` (lines 197, 229-233)

**Estimated Effort:** 20 minutes

---

### 3.4 Document Ordinal Encoding Bias (H1)
**Confidence:** 85% | **Severity:** 🟡 Medium | **Impact:** Known limitation

**Problem:** Ordinal encoding (categorical → integer) hurts linear models by imposing arbitrary ordering. This is a design limitation.

**Evidence:** pairwise_builder.R:144-145

**Recommended Fix:**

**Option A (Major Fix):** Implement one-hot encoding for linear models only:
```r
# Add new function:
apply_onehot_encoder <- function(df, encoder, target_col) {
  for (col in names(encoder$levels_map)) {
    if (col == target_col || !col %in% names(df)) next
    lvls <- encoder$levels_map[[col]]
    for (lvl in lvls[-1]) {  # Drop first to avoid multicollinearity
      df[[paste0(col, "_", lvl)]] <- as.integer(df[[col]] == lvl)
    }
    df[[col]] <- NULL
  }
  df
}

# Modify preprocess_split() to use one-hot for linear models:
encoder <- fit_categorical_encoder(train_df, ds_cfg$target)

# Check if task uses linear models
uses_linear_models <- any(task$model_pairs$single %in% c("logistic_regression", "linear_regression", "svr"))

if (task_name %in% c("classification", "regression") && uses_linear_models) {
  train_df <- apply_onehot_encoder(train_df, encoder, ds_cfg$target)
  test_df <- apply_onehot_encoder(test_df, encoder, ds_cfg$target)
} else {
  # Use ordinal encoding for tree models
  train_df <- apply_categorical_encoder(train_df, encoder, imputer, ds_cfg$target)
  test_df <- apply_categorical_encoder(test_df, encoder, imputer, ds_cfg$target)
}
```

**Option B (Documentation Only):** Add documentation to methodology.md explaining the limitation.

**Recommendation:** For a student project, Option B is acceptable. If time permits, implement Option A.

**Files to Modify:**
- `docs/methodology.md` (add section on encoding limitations)
- OR `scripts/R/pairwise_builder.R` (implement one-hot encoding)

**Estimated Effort:** 1 hour (Option A), 15 minutes (Option B)

---

### 3.5 Consider ID Column Detection Conservative (H5)
**Confidence:** 70% | **Severity:** 🟡 Medium | **Impact:** May remove useful features

**Problem:** `infer_id_columns()` removes ALL unique integer/character columns, potentially removing useful features like timestamps or high-cardinality categorical features.

**Evidence:** pairwise_builder.R:93-96

**Recommended Fix:**

```r
# Replace infer_id_columns() with more conservative version:
infer_id_columns <- function(df, target_col) {
  out <- character(0)
  for (col in names(df)) {
    if (col == target_col) next

    # Only remove columns with clearly ID-like names
    if (tolower(col) %in% c("id", "identifier", "uid", "row_id",
                             "index", "no", "sr_no", "serial")) {
      out <- c(out, col)
    }

    # For all-unique columns, only remove if they look like IDs:
    # - Integer with sequential values
    # - All unique AND name suggests ID
    if (length(unique(df[[col]])) == nrow(df)) {
      if (is.integer(df[[col]])) {
        # Check if sequential (common in row IDs)
        vals <- sort(df[[col]])
        if (all(diff(vals) == 1)) {
          out <- c(out, col)
        }
      } else if (is.character(df[[col]]) || is.factor(df[[col]])) {
        # Check if name suggests ID
        if (tolower(col) %in% c("id", "identifier", "uid", "key")) {
          out <- c(out, col)
        }
      }
    }
  }
  unique(out)
}
```

**Files to Modify:**
- `scripts/R/pairwise_builder.R` (lines 85-100)

**Testing Required:**
- Verify timestamps are not removed
- Verify ZIP codes are not removed (unless explicitly named as ID)

**Estimated Effort:** 30 minutes

---

### 3.6 Add Empty Fold Warning (M4)
**Confidence:** 75% | **Severity:** 🟡 Medium | **Impact:** Unreliable metrics

**Problem:** Stratified K-fold doesn't guard against minority classes with fewer samples than k folds. Some folds get zero samples of that class, making precision/recall unreliable.

**Evidence:** splits.R:39-42

**Recommended Fix:**

```r
# Replace lines 39-42 with:
for (cls in classes) {
  idxs <- which(y == cls)
  if (length(idxs) < k) {
    warning(sprintf(
      "Class '%s' has only %d samples, fewer than k=%d folds. " +
      "Some folds will have zero samples of this class, affecting reliability of metrics.",
      cls, length(idxs), k
    ))
  }
  fold_ids[idxs] <- sample(rep(seq_len(k), length.out = length(idxs)))
}
```

**Files to Modify:**
- `scripts/R/splits.R` (lines 39-42)

**Estimated Effort:** 10 minutes

---

## Priority Tier 4: LOW (Style & Minor Issues)

### 4.1 Remove Redundant `is.nan()` Check (L1)
**Confidence:** 95% | **Severity:** 🔵 Low | **Impact:** Code noise

**Problem:** `is.na()` catches `NaN` too, so `is.nan()` line is redundant.

**Evidence:** pairwise_builder.R:124-125

**Recommended Fix:**

```r
# Remove line 125 (the is.nan() check):
# Keep only line 124:
df[[col]][is.na(df[[col]])] <- med
df[[col]][is.infinite(df[[col]])] <- med
```

**Files to Modify:**
- `scripts/R/pairwise_builder.R` (line 125)

**Estimated Effort:** 2 minutes

---

### 4.2 Remove No-Op Blocks (L2)
**Confidence:** 90% | **Severity:** 🔵 Low | **Impact:** Dead code

**Problem:** Four blocks in config.R assign variables to themselves (no-op).

**Evidence:** config.R:69-71, 73-74, 76-77, 79-80

**Recommended Fix:**

```r
# Remove lines 69-71, 73-74, 76-77, 79-80 entirely
# They do nothing and clutter the code
```

**Files to Modify:**
- `scripts/R/config.R` (lines 69-71, 73-74, 76-77, 79-80)

**Estimated Effort:** 2 minutes

---

### 4.3 Read More Bytes for HTML Detection (L4)
**Confidence:** 85% | **Severity:** 🔵 Low | **Impact:** May miss error pages

**Problem:** HTML check reads only 20 bytes. Error pages with BOM or whitespace prefix may be missed.

**Evidence:** parallel_utils.R:33

**Recommended Fix:**

```r
# Replace line 33 with:
first_bytes <- readBin(dest, raw(), n = min(200, file.info(dest)$size))
```

**Files to Modify:**
- `scripts/R/parallel_utils.R` (line 33)

**Estimated Effort:** 2 minutes

---

### 4.4 Consider Reducing Filelock Timeout (L5)
**Confidence:** 70% | **Severity:** 🔵 Low | **Impact:** Brief hangs

**Problem:** 5-second timeout on file locks. If worker crashes holding lock, others hang 5 seconds per log call.

**Evidence:** logging.R:43

**Recommended Fix:**

```r
# Replace line 43 with:
lock <- filelock::lock(paste0(run_ctx$log_file, ".lock"), timeout = 1000)  # 1 second
```

**Note:** This is optional; 5 seconds is not a major issue.

**Files to Modify:**
- `scripts/R/logging.R` (line 43)

**Estimated Effort:** 2 minutes

---

### 4.5 Document Hardcoded GBM Hyperparameters (L3, L6)
**Confidence:** 90% | **Severity:** 🔵 Low | **Impact:** Limited optimization

**Problem:** Same GBM hyperparameters (n.trees=100, depth=3, shrinkage=0.05) used for all datasets. Exp smoothing uses only 5 alpha values.

**Evidence:** models_classification.R:67, models_regression.R:28, models_timeseries.R:117; models_timeseries.R:68

**Recommended Fix:**

**Option A:** Make hyperparameters configurable via datasets.yaml:
```yaml
# Add to dataset config:
hyperparameters:
  gbm:
    n_trees: 100
    interaction_depth: 3
    shrinkage: 0.05
    n_minobsinnode: 10
  exp_smoothing:
    alphas: [0.1, 0.2, 0.3, 0.4, 0.5, 0.7, 0.9]
```

**Option B:** Document as known limitation in methodology.md

**Recommendation:** Document as limitation. Hyperparameter tuning is out of scope for this project.

**Files to Modify:**
- `docs/methodology.md` (add section on hyperparameters)

**Estimated Effort:** 15 minutes (documentation), 2+ hours (implementation)

---

### 4.6 Add Rolling Splits Warning (L8)
**Confidence:** 80% | **Severity:** 🔵 Low | **Impact:** Silent deviation

**Problem:** `make_rolling_splits` may produce fewer splits than requested for small datasets. No warning emitted.

**Evidence:** splits.R:64 (break without warning)

**Recommended Fix:**

```r
# Replace line 64 with:
if (test_start > n) {
  warning(sprintf(
    "Requested %d rolling splits, but only produced %d due to dataset size (n=%d)",
    n_splits, length(splits), n
  ))
  break
}
```

**Files to Modify:**
- `scripts/R/splits.R` (line 64)

**Estimated Effort:** 5 minutes

---

## Priority Tier 5: IGNORE (Invalid/Overstated)

### 5.1 Duplicate `get_base_seed()` (C3) - IGNORE
**Confidence:** 0% | **Severity:** 🔴 Claimed as Critical

**Reason:** Both functions are identical. No divergence possible unless one is edited separately. Not a bug.

**Action:** None. This is minor code duplication only.

---

### 5.2 Parallel Seeding Conflict (H2) - IGNORE
**Confidence:** 15% | **Severity:** 🟠 Claimed as High

**Reason:** `furrr_options(seed = TRUE)` is designed to work WITH manual `set.seed()` calls. Reproducibility works correctly.

**Action:** None. The reviewer misunderstood furrr's design.

---

### 5.3 Missing `writer.R` (M1) - IGNORE
**Confidence:** 0% | **Severity:** 🟡 Claimed as Medium

**Reason:** `writer.R` EXISTS at `scripts/R/writer.R` (23 lines). Reviewer didn't check file existence.

**Action:** None. File exists and works.

---

### 5.4 AdaBoost Mislabeled (L7) - IGNORE
**Confidence:** 10% | **Severity:** 🔵 Claimed as Low

**Reason:** Lines 81-90 show an explicit WARNING and fallback to GBM. The `actual_model_used` field tracks this change. The comparison is clearly documented, not hidden.

**Action:** None. This is intentional design with proper documentation.

---

## Implementation Order & Timeline

### Phase 1: Critical Fixes (Week 1, Days 1-2)
**Priority:** BLOCKER for valid results

1. **Day 1 (Morning):** Fix C1 - Time series data leakage (2-3 hours)
2. **Day 1 (Afternoon):** Fix C2 - Exogenous variable inequality (1-2 hours)
3. **Day 2 (Morning):** Re-run time series experiments, validate results
4. **Day 2 (Afternoon):** Fix H4, H6 - Empty guards (30 minutes)

**Deliverable:** Validated time series results that can be used in analysis

---

### Phase 2: Robustness Fixes (Week 1, Days 3-4)
**Priority:** Prevents cryptic crashes

1. **Day 3 (Morning):** Fix H7 - Warning flood (30 minutes)
2. **Day 3 (Afternoon):** Fix M3, M5 - Plan check & ARIMA warning (20 minutes)
3. **Day 4 (Morning):** Fix M7, M8, M9 - Metrics improvements (40 minutes)
4. **Day 4 (Afternoon):** Full pipeline test run

**Deliverable:** More robust pipeline with clearer error messages

---

### Phase 3: Code Quality (Week 2, Days 1-2)
**Priority:** Maintainability and documentation

1. **Day 1:** Document H1 ordinal encoding limitation (15 minutes)
2. **Day 1:** Consider H5 ID detection refinement (30 minutes, optional)
3. **Day 1:** Add M4 empty fold warning (10 minutes)
4. **Day 2:** Clean up L1, L2 - Remove redundant code (5 minutes)

**Deliverable:** Better documented, cleaner codebase

---

### Phase 4: Minor Polish (Week 2, Days 3-4)
**Priority:** Nice-to-have improvements

1. **Day 3:** Fix L4, L5, L8 - HTML check, timeout, rolling splits warning (10 minutes)
2. **Day 3:** Document L3, L6 - Hardcoded hyperparameters (15 minutes)
3. **Day 4:** Final code review and testing

**Deliverable:** Polished production-ready pipeline

---

## Testing Checklist

After each phase, run these tests:

### Phase 1 Tests (Critical Fixes)
- [ ] Time series ensemble win rate is no longer 100% (should be realistic 60-90%)
- [ ] ARIMA performance improves when using exogenous variables
- [ ] All 6 time series datasets complete successfully
- [ ] No crashes with zero features or empty test sets

### Phase 2 Tests (Robustness)
- [ ] Warnings report is clean (not flooded with duplicates)
- [ ] Plan correctly resets after parallel run
- [ ] ARIMA warns when all grid search orders fail
- [ ] `ifelse()` replaced with `if...else` in metrics
- [ ] Multiclass AUC failures are logged
- [ ] Column removal logged to audit trail

### Phase 3 Tests (Code Quality)
- [ ] Methodology.md documents ordinal encoding limitation
- [ ] ID detection doesn't remove timestamps
- [ ] Empty fold warnings appear for minority classes
- [ ] No redundant `is.nan()` calls

### Phase 4 Tests (Minor Polish)
- [ ] HTML detection uses 200 bytes
- [ ] Filelock timeout is reasonable
- [ ] Rolling splits warn when producing fewer than requested
- [ ] Hyperparameters documented in methodology

---

## Risk Assessment

### High-Risk Changes (Test Thoroughly)
1. **C1 - TS lag leakage fix:** Major logic change. May introduce bugs. Test all TS datasets.
2. **C2 - ARIMAX implementation:** May require package dependencies. Test with/without forecast package.

### Medium-Risk Changes
3. **H4, H6 - Empty guards:** May cause pipeline to stop where it previously crashed with cryptic errors. Verify this is desired behavior.
4. **H7 - Warning caching:** May affect logic if warnings are used for control flow (unlikely but verify).

### Low-Risk Changes
5. All other changes are primarily code style, logging, and defensive checks.

---

## Success Criteria

### Quantitative
- Time series ensemble win rate: Should drop from 100% to realistic range (expect 70-90%)
- Pipeline crash rate: Should decrease (better error messages prevent confusion)
- Warning report size: Should decrease (no 50x duplicate warnings)

### Qualitative
- Clearer error messages when something goes wrong
- Better audit trail of what features were used
- More fair model comparisons
- Better documented limitations

---

## Backward Compatibility

### Breaking Changes
- **C1 fix:** Will change time series results significantly. Previous analyses will need to be re-run.

### Non-Breaking Changes
- All other fixes are additive (new guards, warnings, logging) or code quality improvements.

### Recommendations
1. Create a new git branch for these fixes (e.g., `fix/code-review-issues`)
2. After Phase 1, tag the commit: `v1.1-critical-fixes`
3. Re-run full pipeline and archive results
4. Update analysis documentation with new results

---

## Estimated Total Effort

| Phase | Tasks | Effort | Priority |
|-------|-------|--------|----------|
| Phase 1 | C1, C2, H4, H6 | 5-6 hours | CRITICAL |
| Phase 2 | H7, M3, M5, M7, M8, M9 | 2 hours | HIGH |
| Phase 3 | H1, H5, M4, L1, L2 | 1 hour | MEDIUM |
| Phase 4 | L3, L4, L5, L6, L8 | 1 hour | LOW |
| **TOTAL** | **All issues** | **9-10 hours** | **-** |

**Recommended Timeline:** 2 weeks (1 week for Phase 1-2, 1 week for Phase 3-4)

---

## Next Steps

1. ✅ Review this action plan
2. ✅ Create feature branch: `git checkout -b fix/code-review-issues`
3. ✅ Start with Phase 1 (C1 - Time series leakage fix)
4. ✅ Commit and test after each fix
5. ✅ Update this document as issues are resolved

---

## Appendix: File Impact Summary

| File | Issues | Total Changes |
|------|--------|---------------|
| `models_timeseries.R` | C1, C2, M5, L6 | 4 |
| `pairwise_builder.R` | H4, H6, H7, H1, H5, L1, M9 | 7 |
| `splits.R` | M4, L8 | 2 |
| `metrics.R` | M7, M8 | 2 |
| `main.R` | M3 | 1 |
| `config.R` | L2 | 1 |
| `parallel_utils.R` | L4 | 1 |
| `logging.R` | L5 | 1 |
| `methodology.md` | H1, L3, L6 | 3 |

**Total Files Modified:** 9 files

---

*Action Plan generated based on T3 Chat code review with confidence scores.*
*Last Updated: 2026-03-03T14:30:45+05:30*
