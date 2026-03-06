# Results Summary

> Key findings from 3,160 model comparisons

---

## Current Note

This page summarizes the earlier aggregate experiment outputs. The current Python pipeline validation, fixes, and post-audit caveats are documented in [python-validation-2026-03-06.md](python-validation-2026-03-06.md).

Important updates since the original aggregate summary:

- classification default pair changed from `decision_tree -> adaboost` to `decision_tree -> random_forest`
- time series should no longer be described as universally favoring `gbm_lag`
- `MAPE` is unreliable for some low-target timeseries datasets
- heavy time-series datasets now use lighter validation controls in shared config

## Overall Results

| Metric | Value |
|--------|-------|
| Total Comparisons | 3,160 |
| Ensemble Win Rate | **68.7%** |
| Mean Difference | 501.03 |

---

## By Task Type

| Task | Comparisons | Ensemble Win % |
|------|-------------|----------------|
| Time Series | 160 | **Historical aggregate only** |
| Regression | 1,200 | **85.5%** |
| Classification | 1,800 | **54.7%** |

---

## By Metric

| Metric | Ensemble Win % | Mean Difference |
|--------|---------------|-----------------|
| RMSE (regression) | 92.4% | +2,432 |
| MAE (regression) | 92.1% | +2,203 |
| R² (regression) | 91.3% | +0.035 |
| SMAPE (time series) | Historical aggregate only | +12.4 |
| MAPE (time series) | 72.1% | +20.3 |
| ROC-AUC (classification) | 65.3% | +0.011 |
| Precision (classification) | 58.0% | +0.025 |
| LogLoss (classification) | 59.7% | -0.662 |
| F1 (classification) | 55.3% | +0.018 |
| Accuracy (classification) | 53.0% | +0.015 |
| Recall (classification) | 37.0% | +0.010 |

---

## By Dataset

| Dataset | Task | Ensemble Win % |
|---------|------|----------------|
| electric_production | Time Series | Historical aggregate only |
| melbourne_temp | Time Series | Historical aggregate only |
| insurance | Regression | 88.8% |
| housing_prices | Regression | 82.2% |
| breast_cancer | Classification | 71.7% |
| heart_disease | Classification | 37.8% |

---

## By Model Pair

| Single Model | Ensemble Model | Win Rate |
|--------------|----------------|----------|
| arima | gbm_lag | Historical aggregate only |
| decision_tree_regressor | gradient_boosting_regressor | 100% |
| exp_smoothing | gbm_lag | Historical aggregate only |
| svr | gradient_boosting_regressor | 82.8% |
| linear_regression | gradient_boosting_regressor | 73.8% |
| naive_bayes | gradient_boosting | 61.7% |
| decision_tree | adaboost | Historical aggregate only |
| logistic_regression | gradient_boosting | 48.7% |

---

## Key Insights

1. **Time Series**: The original aggregate suggested strong GBM-lag performance, but later focused Python validation found dataset-dependent outcomes. `arima` is still better on several datasets.

2. **Regression**: Gradient Boosting Regressor consistently outperforms all single models, especially on error metrics (RMSE, MAE)

3. **Classification**: Results are highly dataset-dependent:
   - Clean, well-separated data (breast_cancer): ensembles win 71.7%
   - Noisy, overlapping data (heart_disease): ensembles only win 37.8%

4. **Metric Matters**: 
   - Ensembles excel at discrimination (ROC-AUX: 65.3%)
   - Ensembles struggle with recall (37.0%) - single models catch more true positives

5. **Model Pairing Matters**: The improvement from ensemble depends heavily on which single model is being "upgraded". The old `decision_tree -> adaboost` pair was later replaced in the default config with `decision_tree -> random_forest`.
6. **Validation outputs now carry caveat context**: low-target `MAPE` and `SMAPE` rows can now be flagged directly in pairwise outputs, which should inform interpretation.

---

## Conclusion

The hypothesis that "ensemble models perform better than single models" is **partially supported**:

- Ensembles win **68.7%** of comparisons overall
- The advantage is strongest in **regression** in the historical aggregate results. Later focused validation showed that **time series results are dataset-dependent**, not universally dominated by one model family.
- Classification results are **context-dependent** - dataset characteristics matter more than model choice

This suggests: **ensemble methods provide a probabilistic advantage, not a guarantee** - their benefit varies by task type, dataset, and metric used for evaluation.
