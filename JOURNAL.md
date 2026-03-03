# Journal

TPSM Project Development Journal

---

## 2026-03-03T17:30:00+05:30

**Task:** Add `--fast` mode to TPSM R pipeline with aggressive parallelization

**What was done:**
- Implemented `--fast` CLI flag for dataset-level parallelism
- Installed required packages: future, furrr, filelock
- Fixed `--workers` CLI bug (parsed but never applied)
- Added auto-detection of CPU cores (sets workers to `cores - 2` in fast mode)
- Ran 5 experiments to validate implementation

**Code changes:**
- `scripts/R/config.R`: Added `--fast` flag parsing
- `scripts/main.R`: Added fast mode detection, worker auto-detect, logging

**Experiments completed:**
1. Sequential baseline (68.1s, 36.7% ensemble win rate)
2. Fast mode 14 workers (58.5s, 1.16x speedup, 39.2% win rate)
3. Fast mode 4 workers (58.3s, 1.17x speedup, 30.0% win rate)
4. Reproducibility test - two fast runs (identical results ✅)
5. Single dataset (22.0s, no speedup confirmed)

**Critical discovery:**
- Different worker counts produce different GBM results
- Sequential and 4-worker mode produce identical electric_production gbm_lag results
- 14-worker mode produces different electric_production gbm_lag results
- Root cause: `furrr_options(seed = TRUE)` partitions RNG streams based on worker count
- Issue is NOT "parallel is non-deterministic"
- Issue IS "different worker configurations produce different RNG states"

**Status:**
- Implementation complete ✅
- Experiments complete ✅
- **BLOCKED for production use** - reproducibility fix required

**Documentation created:**
- `FAST_MODE_IMPLEMENTATION.md` - All code changes
- `FAST_MODE_EXPERIMENTS_PLAN.md` - Experiment plan
- `FAST_MODE_EXPERIMENTS_RESULTS.md` - Detailed results
- `FAST_MODE_FINAL_SUMMARY.md` - Executive summary
- `config/quick_test.yaml` - Test configuration

**Next steps:**
- Try RNG reset fix: `RNGkind()` before `set.seed()`
- Test with 1, 4, 14 workers after fix - all should match
- If fix fails, consider alternative approaches or mark as experimental only

---

## 2026-03-03T18:37:00+05:30

**Task:** Fix reproducibility issue in fast mode (worker count affects GBM results)

**What was done:**
- Applied Fix 1: Enhanced RNG reset in `parallel_utils.R:161-166`
  - Added `normal.kind = "Inversion"` and `sample.kind = "Rejection"` to `RNGkind()` call
  - Added `set.seed(NULL)` to completely reset RNG state before model-specific seed
- Applied Fix 2: Disabled furrr's RNG management in `main.R:99`
  - Changed `furrr_options(seed = TRUE)` to `furrr_options(seed = NULL)`
- Ran verification experiments with 3 configurations
- Compared all 180 metric values across all modes

**Code changes:**
- `scripts/R/parallel_utils.R`: Lines 161-166 (2 new lines)
- `scripts/main.R`: Line 99 (1 character change)

**Verification results:**
1. Sequential baseline (64.1s, electric_production gbm_lag mae = 16.1720263130623)
2. Fast mode 14 workers (59.3s, mae = 16.1720263130623) ✅ MATCHES
3. Fast mode 4 workers (58.1s, mae = 16.1720263130623) ✅ MATCHES

**Critical success:**
- All 180 metric values IDENTICAL across all 3 modes
- Sequential, Fast14, and Fast4 produce identical results
- Worker count no longer affects GBM results
- Fast mode is now reproducible and ready for production use

**Status:**
- Implementation complete ✅
- Experiments complete ✅
- Reproducibility fix VERIFIED ✅
- **READY FOR PRODUCTION USE**

**Documentation created:**
- `FAST_MODE_FIX_VERIFIED.md` - Complete fix summary and verification results

**Next steps:**
- Test with full dataset suite (25 datasets) to verify speedup at scale
- Update project README to document `--fast` flag
