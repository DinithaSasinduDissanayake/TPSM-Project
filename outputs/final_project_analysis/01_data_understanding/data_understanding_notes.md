# Phase 2A Step 1: Data Understanding

Input CSV: outputs/archive/legacy/py_full_no_timeseries_probe/20260421T231947/analysis_ready_pairwise.csv

## What This File Contains

- Rows: 13950
- Columns: 25
- Task types: classification, regression
- Number of datasets: 19
- Number of metrics: 10
- Number of model pairs: 6

Each row is one generated paired comparison between a single model and an ensemble model.
The row is tied to a task type, dataset, fold, repeat, model pair, and metric.

## Readiness Checks

- Time series rows present: FALSE
- All valid_pair values are TRUE: TRUE
- Duplicate rows: 0
- Missing values outside notes column: 0
- Required analysis columns exist: TRUE
- Numeric metric columns are numeric: TRUE
- difference_value / ensemble_better mismatch count: 1

## What We Learned

- The dataset is already in analysis-ready table form.
- Classification and regression rows are present.
- This Step 1 script only checks structure and usability.
- Deeper descriptive summaries, plots, and hypothesis testing should be done in later steps.

## Notes

- The `notes` column can be mostly empty. That is acceptable because it only stores special warnings.
- A mismatch where `difference_value` is exactly zero should be treated as a tie in later analysis.
- Do not treat this file as raw source data. It is generated comparison data.
