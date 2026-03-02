# TPSM Meta-Dataset Generator

This script suite generates run logs and pairwise model-comparison rows for the TPSM project.

## What It Produces

- `model_runs.csv` (raw per-model split metrics)
- `pairwise_differences.csv` (meta-level comparison dataset)
- `run_manifest.json` (config snapshot)
- `run_log.txt` (event log)
- `error_report.json` (written on first failure)

## Design Choices

- Predefined tasks, datasets, model pairs, and split strategy (configured in `scripts/R/config.R`)
- Stop on first fail
- Script does **not** perform hypothesis testing or interpretation

## Run

```bash
Rscript scripts/main.R
```

Optional:

```bash
Rscript scripts/main.R --task classification
Rscript scripts/main.R --output-dir outputs
```

## Required R Packages

- `jsonlite`
- `dplyr`
- `ggplot2`
- `tidyr`
- `rpart`
- `gbm`
- `e1071`
- `forecast`
- `pROC`
- `ada`

If a required package/model path is missing, execution stops and writes `error_report.json`.
