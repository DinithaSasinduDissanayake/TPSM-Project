# Phase 2A Step 3: Descriptive Plot Notes

Step 2 summary folder: outputs/final_project_analysis/02_descriptive_summaries
Main input CSV: outputs/archive/legacy/py_full_no_timeseries_probe/20260421T231947/analysis_ready_pairwise.csv

## Plots Created

- `01_win_rate_by_task_type.png`: compares ensemble win rate excluding ties for classification and regression.
- `02_win_rate_by_dataset.png`: compares ensemble win rate excluding ties across datasets.
- `03_win_rate_by_metric.png`: compares ensemble win rate excluding ties across metrics; MAPE is shown in a caution color.
- `04_win_rate_by_model_pair.png`: compares ensemble win rate excluding ties across model pairs.
- `05_histogram_difference_value.png`: zoomed raw histogram. Keep for internal checking only; not recommended for presentation.
- `06_boxplot_difference_by_metric.png`: limited boxplot by metric. Values are clipped within each metric's 5th to 95th percentile for readability.
- `07_faceted_histogram_difference_by_metric.png`: shows separate metric-wise distributions with free x-axis scales.
- `08_histogram_difference_by_task_type.png`: separates classification and regression distributions.
- `09_win_loss_tie_by_metric.png`: counts how often the ensemble wins, loses, or ties for each metric.

## Why Raw difference_value Is Hard To Plot

The raw `difference_value` column mixes metrics with very different scales. Classification metrics such as accuracy, F1, precision, recall, and ROC AUC are bounded and usually move in small decimals. Regression error metrics such as MAE and RMSE can move by hundreds or thousands because they use the original target units. When all metrics are placed on one raw x-axis, the large regression values compress the small classification values near zero.

## Plain-Language Observations

- The task-type plot shows the strongest task type is `classification` with a non-tie win rate of 87.5%.
- Several datasets have very high ensemble win rates, including airfoil, ccpp, concrete_strength, letter_recognition, magic_gamma.
- The lowest dataset win rates are seen in housing_prices, abalone, heart_disease, breast_cancer, german_credit.
- The highest metric win rates are logloss, roc_auc, accuracy.
- The lowest metric win rates are recall, mape, precision.
- The strongest model-pair win-rate plot is `decision_tree__vs__random_forest` at 92.8%.
- The weakest model-pair win-rate plot is `logistic_regression__vs__gradient_boosting` at 80%.
- The faceted histogram is the clearest plot for explaining `difference_value` shape by metric.
- The task-type histogram shows why classification and regression should not be forced onto one raw x-axis.
- The win/loss/tie chart is the simplest presentation plot for showing how often ensembles perform better.

## Cautions

- These plots are descriptive only. They do not test statistical significance.
- The 50% reference line is visual guidance only, not a hypothesis test.
- Ties are counted separately and excluded from plotted win-rate denominators.
- MAPE is included but visually flagged because the generator warnings identified low-target MAPE risk.
- `05_histogram_difference_value.png` is not recommended for presentation because it still mixes metric scales.
- `06_boxplot_difference_by_metric.png` clips values within each metric for readability, so it should not be used to discuss extreme values.
- Raw `difference_value` is still scale-sensitive, especially across regression and classification metrics.

## Best Plots For Report Or Presentation

- Use `01_win_rate_by_task_type.png` for the high-level task comparison.
- Use `02_win_rate_by_dataset.png` to show variation across datasets.
- Use `03_win_rate_by_metric.png` to explain metric-level differences and flag MAPE.
- Use `07_faceted_histogram_difference_by_metric.png` to explain `difference_value` without mixed-scale distortion.
- Use `08_histogram_difference_by_task_type.png` if the presentation needs a simple classification-versus-regression comparison.
- Use `09_win_loss_tie_by_metric.png` as the clearest beginner-friendly count view.

## Internal-Understanding Plots

- `05_histogram_difference_value.png` is useful only as a quick diagnostic view of the combined raw distribution.
- `06_boxplot_difference_by_metric.png` is useful for checking the middle spread by metric, but remember that extreme values are clipped.

## Next Step

After the descriptive plots are accepted, the next step can be planned separately. No hypothesis testing is done in this script.
