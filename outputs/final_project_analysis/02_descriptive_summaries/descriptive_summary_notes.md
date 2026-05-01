# Phase 2A Step 2: Descriptive Summaries

Input CSV: outputs/archive/legacy/py_full_no_timeseries_probe/20260421T231947/analysis_ready_pairwise.csv
Step 1 context folder: outputs/final_project_analysis/01_data_understanding

## Overall Pattern

- Total valid comparison rows: 13950
- Datasets: 19
- Task types: 2
- Metrics: 10
- Model pairs: 6
- Ensemble wins: 11910
- Single-model wins: 1779
- Ties: 261
- Ensemble win rate: 85.38%
- Mean difference_value: 566.112149
- Median difference_value: 0.116074

This is descriptive analysis only. These values describe the generated comparison rows; they are not hypothesis-test results.

## Task Types

- regression: 5400 comparisons, 86.19% ensemble win rate
- classification: 8550 comparisons, 84.87% ensemble win rate

## Datasets That Stand Out

Highest ensemble win rates:
- airfoil: 100%
- ccpp: 100%
- concrete_strength: 100%
- letter_recognition: 100%
- magic_gamma: 99.89%

Lowest ensemble win rates:
- housing_prices: 44.17%
- heart_disease: 53.89%
- abalone: 56.5%
- breast_cancer: 64%
- german_credit: 73.56%

## Metrics That Stand Out

Highest ensemble win rates:
- logloss: 93.61%
- roc_auc: 90.95%
- r2: 88.15%

Lowest ensemble win rates:
- recall: 73.82%
- precision: 80.91%
- mape: 82.44%

## Model Pairs That Stand Out

Highest ensemble win rates:
- decision_tree__vs__random_forest: 91.16%
- svr__vs__gradient_boosting_regressor: 88.89%
- naive_bayes__vs__gradient_boosting: 87.54%

Lowest ensemble win rates:
- logistic_regression__vs__gradient_boosting: 75.89%
- decision_tree_regressor__vs__gradient_boosting_regressor: 82.83%
- linear_regression__vs__gradient_boosting_regressor: 86.83%

## Cautions

- Ties are counted separately. They are not counted as ensemble wins. Tie count: 261
- MAPE is present with 1350 rows and should be treated carefully because Step 1 and generator warnings flagged low-target MAPE risk.
- Descriptive win rates do not prove the claim. They only show patterns that should be checked later.

## Questions For The Next Step

- Which patterns are easiest to explain visually?
- Should MAPE be excluded from the main visual story and kept as a caution/sensitivity item?
- Do task types, metrics, or model pairs show noticeably different behavior?
- Which grouped summaries should be turned into simple plots in Step 3?
