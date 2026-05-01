# TPSM Phase 1 Project Map

This document explains the recovered foundation of the TPSM project before final
analysis and report work begins.

## Project Claim

The selected claim is:

> Ensemble models perform better than single models in many prediction tasks.

The project treats trained-model benchmark results as generated statistical data.
The generator trains single and ensemble models on the same dataset, split, and
metric, then writes paired comparison rows for statistical analysis.

## Current Direction

The final project direction is classification and regression only.

Time series was explored earlier, but it is excluded from the final direction
because it introduced extra modeling and runtime complexity that made the story
harder to explain. The recovered classification/regression evidence is already
large enough for the intended statistical analysis.

## Recovered Evidence

Best recovered evidence CSV:

```text
outputs/archive/legacy/py_full_no_timeseries_probe/20260421T231947/analysis_ready_pairwise.csv
```

This CSV contains:

- 13,950 paired comparison rows
- 19 datasets
- 10 classification datasets
- 9 regression datasets
- no time-series rows
- all rows marked as valid pairs

Related recovered config snapshot:

```text
outputs/archive/legacy/py_full_no_timeseries_probe/20260421T231947/config_snapshot.yaml
```

The folder is archived because of repository reorganization, not because the
output is invalid.

Important note: `final_outputs/` is only a small later subset with two datasets.
It should not be treated as the real Phase 1 foundation.

## Python Generator

The recovered Python generator lives in:

```text
code/python/tpsm/
```

Important files:

- `main.py` - command-line entry point and resumable runner
- `config.py` - YAML config loading and dataset validation
- `data_loader.py` - local dataset loading and download fallback
- `pipeline.py` - preprocessing, split execution, and pairwise rows
- `splits.py` - repeated k-fold and rolling-origin split helpers
- `models.py` - classification, regression, and time-series model wrappers
- `metrics.py` - metric calculation and metric direction rules
- `writer.py` - CSV writing and `analysis_ready_pairwise.csv` schema

## Configs

Full recovered no-time-series config:

```text
config/generated/full_no_timeseries.generated.yaml
```

Tiny demo config:

```text
config/generated/demo_no_timeseries_tiny.yaml
```

The tiny demo config is for live demonstration only. It does not replace the
13,950-row recovered evidence CSV.

## Safe Demo Command

Use this command to demonstrate that the generator works without running the full
benchmark:

```bash
.venv/bin/python -m code.python.tpsm.main --config config/generated/demo_no_timeseries_tiny.yaml --output-dir outputs/active/demo_no_timeseries_tiny_live
```

Expected demo outputs:

- `model_runs.csv`
- `pairwise_differences.csv`
- `analysis_ready_pairwise.csv`
- `dataset_cleaning_summary.csv`
- `run_manifest.json`
- `run_log.txt`

Do not run the full 19-dataset benchmark during a live demo.

## Phase 1 Completed

- Recovered the Python generator foundation.
- Identified the best recovered evidence CSV.
- Verified that the current writer schema matches the recovered CSV schema.
- Added a tiny no-time-series demo config.
- Verified the tiny generator path produces valid model and pairwise outputs.
- Fixed R analysis compatibility with Python boolean values.

## Not Completed Yet

- Final statistical analysis of the 13,950-row evidence CSV.
- Final chart/table selection.
- Final report and presentation wording.
- Final cleanup of old or misleading result folders.

## Next Phase

Phase 2 should analyze the recovered `analysis_ready_pairwise.csv` using R:

- descriptive summaries
- ensemble win rates
- paired tests and confidence intervals
- metric-level and dataset-level interpretation
- final report and presentation material
