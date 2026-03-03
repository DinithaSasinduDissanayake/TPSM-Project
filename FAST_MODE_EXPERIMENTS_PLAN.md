# Fast Mode Experiments

## Experiment 1: Sequential Execution (Default Mode)
**Date:** 2026-03-03
**Config:** `config/quick_test.yaml` (3 TS datasets, 5 splits each)
**Command:** `Rscript scripts/main.R --config config/quick_test.yaml`
**Mode:** Sequential (1 worker)

### Objective
- Establish baseline performance without parallelism
- Verify default behavior unchanged

### Expected Results
- ~2-3 minutes total runtime
- 3 datasets x 5 splits x 3 models = 45 model fits
- 2 model pairs x 5 splits x 3 datasets = 30 pairwise comparisons

---

## Experiment 2: Fast Mode (Auto-Detect Workers)
**Date:** 2026-03-03
**Config:** `config/quick_test.yaml` (3 TS datasets, 5 splits each)
**Command:** `Rscript scripts/main.R --fast --config config/quick_test.yaml`
**Mode:** Parallel (14 workers auto-detected)

### Objective
- Measure speedup with fast mode
- Verify all 3 datasets run in parallel

### Expected Results
- ~30-45 seconds total runtime (3-5x speedup)
- All 3 datasets should complete nearly simultaneously
- Output should be identical to Experiment 1

---

## Experiment 3: Custom Worker Count (4 Workers)
**Date:** 2026-03-03
**Config:** `config/quick_test.yaml` (3 TS datasets, 5 splits each)
**Command:** `Rscript scripts/main.R --fast --workers 4 --config config/quick_test.yaml`
**Mode:** Parallel (4 workers explicit)

### Objective
- Test explicit worker specification
- Verify worker count override works

### Expected Results
- ~1-1.5 minutes total runtime (2-3x speedup)
- Only 4 workers active
- Output should be identical to Experiments 1 and 2

---

## Experiment 4: Reproducibility Test
**Date:** 2026-03-03
**Config:** `config/quick_test.yaml` (3 TS datasets, 5 splits each)
**Command:** Run Experiment 2 twice with `--fast`
**Mode:** Parallel (14 workers)

### Objective
- Verify that parallel execution produces identical results across runs
- Test that `furrr_options(seed = TRUE)` ensures reproducibility

### Expected Results
- Byte-for-byte identical output files
- Same metrics, same ensemble win rates

---

## Experiment 5: Single Dataset Fast Mode
**Date:** 2026-03-03
**Config:** `config/debug_ts_single.yaml` (1 TS dataset)
**Command:** `Rscript scripts/main.R --fast --config config/debug_ts_single.yaml`
**Mode:** Parallel (14 workers, but only 1 dataset)

### Objective
- Demonstrate that fast mode with single dataset shows NO speedup
- Prove that speedup comes from dataset-level parallelism

### Expected Results
- Runtime identical to sequential mode
- All 14 workers idle except 1
- Output identical to default mode

---

## Metrics to Collect

For each experiment, collect:

### Performance
- Wall clock time (using `time` command)
- CPU utilization (using `top` or `htop`)
- Memory usage (using `free -h`)

### Output Quality
- Number of model_runs rows
- Number of pairwise_differences rows
- Ensemble win rate per dataset
- Any errors or warnings

### Reproducibility
- Compare CSV outputs with `diff`
- Compare ensemble win rates across runs

---

## Expected Speedup Analysis

### Theoretical Speedup
- With 3 datasets and 14 workers:
  - All 3 datasets run in parallel
  - Task bottleneck becomes slowest dataset
  - Expected: ~3x speedup (3 datasets in parallel)

### With 4 workers:
- 3 datasets, 4 workers
- Expected: ~2.5-3x speedup

### With single dataset:
- 1 dataset, 14 workers
- Expected: No speedup (only 1 dataset to parallelize)

---

## Success Criteria

- [ ] All experiments complete without errors
- [ ] Fast mode shows 2-3x speedup with 3 datasets
- [ ] Single dataset fast mode shows no speedup
- [ ] Outputs are identical between modes (byte-level)
- [ ] Reproducibility verified (identical outputs across multiple runs)
- [ ] Memory usage stays reasonable (< 10 GB)
- [ ] No race conditions or corrupt logs

---

## Log Files Structure

Each experiment will create its own output directory:
```
outputs/quick_test_seq_20260303_HHMMSS/
outputs/quick_test_fast14_20260303_HHMMSS/
outputs/quick_test_fast4_20260303_HHMMSS/
outputs/quick_test_repro1_20260303_HHMMSS/
outputs/quick_test_repro2_20260303_HHMMSS/
outputs/quick_test_single_20260303_HHMMSS/
```

Each contains:
- `run_manifest.json`
- `run_log.txt`
- `model_runs.csv`
- `pairwise_differences.csv`
- `warnings_report.json` (if any)
- `warnings_summary.json` (if any)

---

## Analysis Plan

After all experiments complete:

1. **Performance Analysis:**
   - Compare wall clock times
   - Calculate actual speedup vs theoretical
   - Analyze CPU utilization patterns

2. **Quality Analysis:**
   - Verify ensemble win rates are realistic (not 100%)
   - Check for any GBM leakage (should be 70-90% range)

3. **Reproducibility Analysis:**
   - Diff CSV files between runs
   - Verify seeds are working correctly

4. **Resource Usage:**
   - Memory usage per worker
   - Any memory leaks or accumulation

5. **Log Analysis:**
   - Check for any corrupted log entries
   - Verify filelock is working (no interleaved JSONL)
