# Fast Mode Experiments - Final Summary

**Date:** 2026-03-03
**Status:** All 5 experiments completed
**Conclusion:** Critical reproducibility issue found - **different worker counts produce different GBM results**

---

## Quick Results

| Experiment | Mode | Workers | Runtime | Speedup | GBM Reproducibility |
|-----------|------|---------|----------|----------|---------------------|
| 1 | Sequential | 1 | 68.1s | 1.00x | Baseline (Result A) |
| 2 | Fast | 14 | 58.5s | 1.16x | Result B (self-consistent ✅) |
| 3 | Fast | 4 | 58.3s | 1.17x | Result A (matches seq ✅) |
| 4 | Fast | 14 | 59.3s | 1.15x | Result B (identical to #2 ✅) |
| 5 | Fast | 14 | 22.0s | N/A | Single dataset only |

---

## Critical Discovery: Worker Count Affects GBM Results

**The problem is NOT "sequential vs parallel" - it's "different worker configurations produce different RNG states"**

Evidence:
- **Sequential (1 worker):** electric_production gbm_lag mae = 16.172 (Result A)
- **Fast mode (4 workers):** electric_production gbm_lag mae = 16.172 (Result A) **MATCHES!**
- **Fast mode (14 workers):** electric_production gbm_lag mae = 17.134 (Result B) **DIFFERS!**
- **Fast mode (14 workers, run 2):** electric_production gbm_lag mae = 17.134 (Result B) **MATCHES!**

### What This Means

1. **Fast mode IS reproducible** with itself (same worker count = same results)
2. **Different worker counts produce different results** (4 workers ≠ 14 workers)
3. **4 workers happens to match sequential** due to RNG stream partitioning coincidence
4. **Root cause:** `furrr_options(seed = TRUE)` partitions L'Ecuyer-CMRG RNG streams based on worker count

### Why This Happens

furrr uses L'Ecuyer-CMRG RNG to generate parallel-safe random streams:
- With N workers, it divides the RNG stream into N independent substreams
- Each worker gets a different substream
- The partitioning depends on N (worker count)
- Even though `set.seed(model_seed)` is called before each model, there may be residual state differences or the initial RNG state entering the worker differs

---

## Performance Findings

### Speedup is Limited with Small Number of Datasets

- **Expected speedup:** 3x (3 datasets in parallel)
- **Actual speedup:** 1.16x (with 14 workers)
- **Efficiency:** 39% of theoretical

**Why limited:**
- Only 3 datasets to parallelize
- Workload imbalance: metro_traffic (slowest) dominates runtime
- 14 workers is overkill - 4 workers sufficient for 3 datasets
- No performance difference between 4 workers and 14 workers

### Single Dataset Shows No Speedup

- **Experiment 5:** Single dataset (melbourne_temp) took 22s
- **Expected:** No speedup (only 1 dataset to parallelize)
- **Confirmed:** Dataset-level parallelism requires multiple datasets for speedup

---

## Fix Options

### Option 1: Force Complete RNG Reset (Recommended - Try First)

Add before `set.seed(model_seed)` at `parallel_utils.R:163`:
```r
RNGkind("Mersenne-Twister", sample.kind = "Rounding")
set.seed(42)  # Reset to known baseline
set.seed(model_seed)  # Then set to model-specific seed
```

**Rationale:** Force RNG to exact same state in all workers by resetting to a known baseline before applying model-specific seed.

### Option 2: Disable furrr's RNG Management

Change `furrr_options(seed = TRUE)` to `furrr_options(seed = FALSE)` in `main.R`

**Rationale:** Rely entirely on manual `set.seed()` calls, bypassing furrr's internal RNG stream partitioning.

**Risk:** May lose some safety guarantees furrr provides for parallel execution.

### Option 3: Accept Non-Determinism (Last Resort)

- Document that fast mode results may vary with worker count
- Only use fast mode for exploratory analysis
- Use sequential mode for production experiments requiring reproducibility

---

## Recommendations

### Immediate

1. **Do NOT use fast mode for production** until reproducibility is fixed
2. **Try Option 1 fix first** - most conservative approach
3. **Test with 1, 4, 14 workers** after fix - all should produce identical results

### Before Production Use

1. Test with full 6 timeseries datasets to see true speedup
2. Test classification/regression tasks to verify reproducibility across model types
3. Add unit tests for model reproducibility in parallel mode
4. Document reproducibility guarantees clearly

### Long-term

1. Consider adding `--validate-reproducibility` flag to compare with baseline
2. Benchmark with full dataset suite (10 + 9 + 6 = 25 datasets)
3. Consider implementing split-level parallelization for more granular control

---

## Files Modified

1. `scripts/R/config.R` - Added `--fast` flag parsing
2. `scripts/main.R` - Added fast mode detection, worker auto-detect, `--workers` bug fix

## Files Created

1. `FAST_MODE_IMPLEMENTATION.md` - All code changes documented
2. `FAST_MODE_EXPERIMENTS_PLAN.md` - Experiment plan
3. `FAST_MODE_EXPERIMENTS_RESULTS.md` - Detailed results and analysis
4. `FAST_MODE_FINAL_SUMMARY.md` - This file
5. `config/quick_test.yaml` - Quick test config (3 TS datasets, 5 splits each)

## Output Directories

```
outputs/
├── quick_test_seq/20260303T162135/  # Experiment 1: Sequential
├── quick_test_fast14/20260303T162331/  # Experiment 2: Fast mode 14 workers
├── quick_test_repro1/20260303T170304/  # Experiment 4a: Fast mode repro run 1
├── quick_test_repro2/20260303T170407/  # Experiment 4b: Fast mode repro run 2
├── quick_test_fast4/20260303T182424/   # Experiment 3: Fast mode 4 workers
└── quick_test_single/20260303T182550/  # Experiment 5: Single dataset
```

## Log Files

```
fast_mode_exp1_seq.log          # Experiment 1 output
fast_mode_exp2_fast14.log       # Experiment 2 output
fast_mode_exp4_repro1.log      # Experiment 4a output
fast_mode_exp4_repro2.log      # Experiment 4b output
fast_mode_exp3_fast4.log       # Experiment 3 output
fast_mode_exp5_single.log      # Experiment 5 output
```

---

## Conclusion

Fast mode is implemented and functional, but **cannot be used for production** until the reproducibility issue is resolved.

The issue is more complex than initially thought: different worker counts produce different GBM results due to furrr's RNG stream partitioning. A simple `RNGkind()` fix may not be sufficient.

**Next steps:**
1. Try Option 1 fix (complete RNG reset)
2. If that fails, try Option 2 (disable furrr RNG management)
3. If all fixes fail, document as exploratory-only feature

**Success criteria for production use:**
- Sequential, 4-worker, and 14-worker modes produce identical GBM results
- All models (not just ARIMA and exp_smoothing) are reproducible across worker counts
- Speedup is verified with larger dataset counts (6+ datasets)
