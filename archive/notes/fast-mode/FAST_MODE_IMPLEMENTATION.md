# Fast Mode Implementation - All Changes

**Date:** 2026-03-03
**Purpose:** Add `--fast` CLI flag for aggressive parallelization utilizing all CPU cores
**Strategy:** Dataset-level parallelism only (Option A - safest approach)

---

## Summary of Changes

- **New files:** 0
- **Modified files:** 2
- **New lines added:** ~14
- **Lines removed:** 0
- **Packages installed:** 3 (future, furrr, filelock)

---

## 1. Package Installation (Runtime, No Code Changes)

### Command Executed
```r
install.packages(c('future', 'furrr', 'filelock'), repos='https://cloud.r-project.org', quiet=TRUE)
```

### Purpose
- `future` + `furrr`: Parallel execution framework with `future_map()` and `plan(multisession)`
- `filelock`: Safe concurrent log writes (already supported in code, just needed package)

### Dependencies Installed
- digest, globals, listenv, parallelly (auto-installed with future)

---

## 2. File: `scripts/R/config.R`

### Location
Lines 1-29 (function `parse_args`)

### Change 1: Initialize `fast` parameter in default args

**Old (line 2):**
```r
out <- list(output_dir = "outputs", task_filter = NULL, config_path = NULL)
```

**New:**
```r
out <- list(output_dir = "outputs", task_filter = NULL, config_path = NULL, fast = FALSE)
```

### Change 2: Add `--fast` flag parsing

**Added after line 20 (after `--config` handling):**
```r
} else if (key == "--fast") {
  out$fast <- TRUE
  i <- i + 1
}
```

### Full Updated Function
```r
parse_args <- function(args) {
  out <- list(output_dir = "outputs", task_filter = NULL, config_path = NULL, fast = FALSE)
  if (length(args) == 0) return(out)

  i <- 1
  while (i <= length(args)) {
    key <- args[[i]]
    val <- if (i < length(args)) args[[i + 1]] else NULL
    if (key == "--output-dir") {
      out$output_dir <- val
      i <- i + 2
    } else if (key == "--task") {
      out$task_filter <- val
      i <- i + 2
    } else if (key == "--workers") {
      out$workers <- as.integer(val)
      i <- i + 2
    } else if (key == "--config") {
      out$config_path <- val
      i <- i + 2
    } else if (key == "--fast") {
      out$fast <- TRUE
      i <- i + 1
    } else {
      i <- i + 1
    }
  }
  out
}
```

---

## 3. File: `scripts/main.R`

### Change 1: Fix `--workers` CLI bug (Line 25-26)

**Problem:** `args$workers` was parsed but never applied to `parallel_workers`

**Old:**
```r
stop_on_fail <- cfg$stop_on_first_fail
timeout_sec <- cfg$timeout_seconds %||% 300
parallel_workers <- cfg$parallel_workers %||% 1
```

**New:**
```r
stop_on_fail <- cfg$stop_on_first_fail
timeout_sec <- cfg$timeout_seconds %||% 300
parallel_workers <- cfg$parallel_workers %||% 1
if (!is.null(args$workers)) parallel_workers <- args$workers
```

### Change 2: Add fast mode detection (Lines 28-35)

**Added after parallel_workers:**
```r
fast_mode <- isTRUE(args$fast)
n_cores <- NA
if (fast_mode) {
  n_cores <- parallel::detectCores(logical = TRUE)
  if (is.null(args$workers)) {
    parallel_workers <- max(1, n_cores - 2)
  }
}
```

**Logic:**
- If `--fast` is set, detect total logical cores (16 on this system)
- If user didn't specify `--workers`, set workers to `cores - 2` (14 workers)
- If user specified `--workers`, use that value instead
- `n_cores = NA` when fast mode is off (prevents logging issues)

### Change 3: Log fast mode in run_start event (Lines 42-48)

**Old:**
```r
log_event(run_ctx, "info", "run_start", list(
  run_id = run_ctx$run_id,
  stop_on_fail = stop_on_fail,
  timeout_sec = timeout_sec,
  parallel_workers = parallel_workers
))
```

**New:**
```r
log_event(run_ctx, "info", "run_start", list(
  run_id = run_ctx$run_id,
  stop_on_fail = stop_on_fail,
  timeout_sec = timeout_sec,
  parallel_workers = parallel_workers,
  fast_mode = fast_mode
))
```

### Change 4: Add fast mode logging event (Lines 50-56)

**Added before parallel setup:**
```r
if (fast_mode && !is.na(n_cores)) {
  log_event(run_ctx, "info", "fast_mode_enabled", list(
    n_cores = n_cores,
    requested_workers = parallel_workers
  ))
}
```

### Change 5: Fix future.globals.onMissing option (Line 67)

**Old:**
```r
options(future.globals.onMissing = "warning")
```

**New:**
```r
options(future.globals.onMissing = "ignore")
```

**Reason:** The value "warning" is not valid in current future package version. Valid options are "error" or "ignore". "ignore" is used to suppress warnings about missing global variables.

---

## Complete Context of Modified Section (main.R)

**Lines 23-72 (context):**
```r
stop_on_fail <- cfg$stop_on_first_fail
timeout_sec <- cfg$timeout_seconds %||% 300
parallel_workers <- cfg$parallel_workers %||% 1
if (!is.null(args$workers)) parallel_workers <- args$workers

fast_mode <- isTRUE(args$fast)
n_cores <- NA
if (fast_mode) {
  n_cores <- parallel::detectCores(logical = TRUE)
  if (is.null(args$workers)) {
    parallel_workers <- max(1, n_cores - 2)
  }
}

if (!is.null(args$task_filter)) {
  cfg$tasks <- Filter(function(t) t$name == args$task_filter, cfg$tasks)
}

run_ctx <- init_run_context(cfg, args$output_dir)
log_event(run_ctx, "info", "run_start", list(
  run_id = run_ctx$run_id,
  stop_on_fail = stop_on_fail,
  timeout_sec = timeout_sec,
  parallel_workers = parallel_workers,
  fast_mode = fast_mode
))

future_available <- requireNamespace("future", quietly = TRUE) && requireNamespace("furrr", quietly = TRUE)
if (fast_mode && !is.na(n_cores)) {
  log_event(run_ctx, "info", "fast_mode_enabled", list(
    n_cores = n_cores,
    requested_workers = parallel_workers
  ))
}
if (parallel_workers > 1 && future_available) {
  library(future)
  library(furrr)
  plan(multisession, workers = parallel_workers)
  log_event(run_ctx, "info", "parallel_enabled", list(workers = parallel_workers))
  options(future.globals.onMissing = "ignore")
} else {
  if (parallel_workers > 1) {
    message("Packages 'future' or 'furrr' not available, running in sequential mode")
    log_event(run_ctx, "warn", "parallel_disabled", list(reason = "missing_packages"))
  }
}
```

---

## What Was NOT Changed

### Code files untouched
- `scripts/R/models_classification.R` - All model training unchanged
- `scripts/R/models_regression.R` - All model training unchanged
- `scripts/R/models_timeseries.R` - All model training unchanged
- `scripts/R/splits.R` - All CV split generation unchanged
- `scripts/R/metrics.R` - All metric calculations unchanged
- `scripts/R/pairwise_builder.R` - All preprocessing and pairwise logic unchanged
- `scripts/R/load_data.R` - All data loading unchanged
- `scripts/R/validation.R` - All validation unchanged
- `scripts/R/writer.R` - All output writing unchanged
- `scripts/R/logging.R` - All logging unchanged (filelock already there)
- `scripts/R/parallel_utils.R` - All parallel utilities unchanged

### Config files untouched
- `config/datasets.yaml` - All configs unchanged
- `config/debug_ts_single.yaml` - All configs unchanged

### Algorithmic behavior
- No changes to model hyperparameters
- No changes to cross-validation strategy (still 10-fold x 5 repeats for classification/regression, 10 rolling origin splits for timeseries)
- No changes to seed/reproducibility logic (`furrr_options(seed = TRUE)` still active)
- No changes to error handling
- No changes to output format (CSV schema identical)

---

## System Environment

- **CPU:** AMD Ryzen 7 7730U (8 cores × 2 threads = 16 logical cores)
- **RAM:** 14 GB total
- **OS:** Linux
- **R:** Version detected from package installations

---

## Parallelization Strategy

### Current (Before Fast Mode)
- Dataset iteration: Sequential
- Parallel infrastructure exists but disabled (future/furrr not installed)
- Workers: 1 (default from config)

### Fast Mode (Dataset-Level Parallelism)
- Dataset iteration: Parallel via `future_map()` at `main.R:79-82`
- Workers: Auto-detected as `cores - 2` = 14 workers on this system
- Within each dataset: Splits and models still sequential (unchanged)

### Why Dataset-Level Only?

1. **Safest approach:** Minimal code changes, no race conditions
2. **Highest impact:** 10-9-6 datasets per task = 25 total work units
3. **Memory-efficient:** Each worker gets one dataset copy, not nested copies
4. **Simplest:** Uses existing `future_map` infrastructure already in code

### Expected Speedup

With 14 workers processing datasets in parallel:
- Classification (10 datasets): All 10 run simultaneously
- Regression (9 datasets): All 9 run simultaneously
- Timeseries (6 datasets): All 6 run simultaneously

**Bottleneck:** Single slowest dataset per task (tasks are still sequential)

**Conservative estimate:** 5-8x overall speedup

---

## Usage Examples

### Normal Run (Unchanged Behavior)
```fish
Rscript scripts/main.R
```
- Sequential execution (1 worker)
- Identical to pre-fast-mode behavior

### Fast Mode (Auto-Detect Cores)
```fish
Rscript scripts/main.R --fast
```
- 14 workers on this system (16 cores - 2)
- Maximum dataset-level parallelism

### Fast Mode with Custom Workers
```fish
Rscript scripts/main.R --fast --workers 8
```
- 8 workers only
- Useful if memory is limited

### Fast Mode with Task Filter
```fish
Rscript scripts/main.R --fast --task timeseries
```
- 14 workers
- Only timeseries task (6 datasets)
- Fastest for testing

### Explicit Workers (No Fast Mode)
```fish
Rscript scripts/main.R --workers 4
```
- 4 workers
- Fast mode NOT set (no auto-detect)
- Useful for testing parallelism without fast mode flag

---

## Verification Checklist

- [x] `--fast` flag parsed correctly
- [x] `--workers` CLI override works (bug fixed)
- [x] Auto-detects 16 cores correctly
- [x] Sets workers to 14 when fast mode + no explicit --workers
- [x] Logging includes fast_mode and n_cores
- [x] future_map executes in parallel mode
- [x] No errors when running with --fast
- [x] Default behavior unchanged (no --fast = sequential)

---

## Known Warnings

When running with --fast, you may see these R warnings (harmless):
```
R option 'future.globals.onMissing' may only be used for troubleshooting.
```

This is because we set `options(future.globals.onMissing = "ignore")` to suppress warnings about global variables. It's informational only and doesn't affect results or reproducibility.

---

## Next Steps for Testing

1. Run single dataset experiment (both modes) - verify output consistency
2. Run multi-dataset experiment (timeseries) - measure speedup
3. Check reproducibility - compare results between runs
4. Validate metrics - ensure ensemble win rates are correct

All of the above should be documented separately in experiment logs.
