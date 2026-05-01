# Phase 2A Step 4: Hypothesis Testing

Input CSV: outputs/archive/legacy/py_full_no_timeseries_probe/20260421T231947/analysis_ready_pairwise.csv
Output folder: outputs/final_project_analysis/04_hypothesis_testing
Alpha level: 0.05

## Main Hypothesis

The main analysis uses win/loss outcomes instead of raw metric differences.

- H0: ensemble win rate = 50%
- H1: ensemble win rate > 50%

A win means `difference_value > 0`. A single-model win means `difference_value < 0`. A tie means `difference_value == 0`.

Ties are counted and reported, but they are not counted as ensemble wins and they are not included in the binomial-test denominator.

## Main Test Result, Excluding MAPE

- Ensemble wins: 10797
- Single-model wins: 1542
- Ties: 261
- Tested non-tie rows: 12339
- Observed ensemble win rate among non-ties: 87.5%
- Test used: Exact one-sided binomial test
- 95% confidence interval for estimated win proportion: 86.91% to 88.08%
- p-value: < 0.001
- Decision at alpha = 0.05: reject H0

Interpretation: if the true ensemble win rate were only 50%, this p-value is the probability of seeing a win count this high or higher just by random chance under the null model.

## Sensitivity Test, Including MAPE

- Ensemble wins: 11910
- Single-model wins: 1779
- Ties: 261
- Tested non-tie rows: 13689
- Observed ensemble win rate among non-ties: 87%
- 95% confidence interval for estimated win proportion: 86.43% to 87.56%
- p-value: < 0.001
- Decision at alpha = 0.05: reject H0

This checks whether the headline conclusion changes when MAPE is included. MAPE is kept out of the headline result because it can be unstable when target values are very small.

## Extra Tests

- `task_level_win_rate_tests_excluding_mape.csv` repeats the win-rate test separately for classification and regression.
- `metric_level_win_rate_tests.csv` repeats the win-rate test separately for each metric.
- `difference_tests_by_metric.csv` gives secondary one-sided t-tests on `difference_value` within each metric.

The difference-value tests should not be the main evidence because raw `difference_value` has different units for different metrics. For example, accuracy and F1 are small decimal-scale metrics, while MAE and RMSE are in original target units.

## What We Can Conclude

For this recovered paired-comparison dataset, ensemble models win significantly more often than 50% of the non-tied comparisons in the headline analysis.

## What We Cannot Overclaim

- This does not prove ensembles are always better.
- The rows are split-level paired comparisons, so many rows come from the same datasets, model pairs, and metrics. The binomial test is a simple course-appropriate test, but it treats tested rows as Bernoulli trials.
- A statistically significant win rate does not automatically mean every individual dataset, model pair, or metric favors ensembles.
- MAPE results should be interpreted cautiously because MAPE can behave poorly when actual target values are near zero.

## Output Files

- `hypothesis_test_summary.csv`: quick map of Step 4 output files.
- `headline_win_rate_tests.csv`: main and sensitivity win-rate tests.
- `task_level_win_rate_tests_excluding_mape.csv`: optional tests by task type.
- `metric_level_win_rate_tests.csv`: optional tests by metric.
- `all_win_rate_tests.csv`: combined win-rate test table.
- `difference_tests_by_metric.csv`: secondary difference-value tests by metric.
- `analysis_method_decisions.csv`: short decision table explaining included and excluded statistical methods.
- `hypothesis_testing_notes.md`: this explanation.
