# Results Summary

> Key findings from 3,160 model comparisons

---

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
| Time Series | 160 | **100%** |
| Regression | 1,200 | **85.5%** |
| Classification | 1,800 | **54.7%** |

---

## By Metric

| Metric | Ensemble Win % | Mean Difference |
|--------|---------------|-----------------|
| RMSE (regression) | 92.4% | +2,432 |
| MAE (regression) | 92.1% | +2,203 |
| R² (regression) | 91.3% | +0.035 |
| SMAPE (time series) | 100% | +12.4 |
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
| electric_production | Time Series | 100% |
| melbourne_temp | Time Series | 100% |
| insurance | Regression | 88.8% |
| housing_prices | Regression | 82.2% |
| breast_cancer | Classification | 71.7% |
| heart_disease | Classification | 37.8% |

---

## By Model Pair

| Single Model | Ensemble Model | Win Rate |
|--------------|----------------|----------|
| arima | gbm_lag | 100% |
| decision_tree_regressor | gradient_boosting_regressor | 100% |
| exp_smoothing | gbm_lag | 100% |
| svr | gradient_boosting_regressor | 82.8% |
| linear_regression | gradient_boosting_regressor | 73.8% |
| naive_bayes | gradient_boosting | 61.7% |
| decision_tree | adaboost | 53.8% |
| logistic_regression | gradient_boosting | 48.7% |

---

## Key Insights

1. **Time Series**: GBM with lag features completely dominates traditional statistical methods (100% win rate across all metrics)

2. **Regression**: Gradient Boosting Regressor consistently outperforms all single models, especially on error metrics (RMSE, MAE)

3. **Classification**: Results are highly dataset-dependent:
   - Clean, well-separated data (breast_cancer): ensembles win 71.7%
   - Noisy, overlapping data (heart_disease): ensembles only win 37.8%

4. **Metric Matters**: 
   - Ensembles excel at discrimination (ROC-AUX: 65.3%)
   - Ensembles struggle with recall (37.0%) - single models catch more true positives

5. **Model Pairing Matters**: The improvement from ensemble depends heavily on which single model is being "upgraded"

---

## Conclusion

The hypothesis that "ensemble models perform better than single models" is **partially supported**:

- Ensembles win **68.7%** of comparisons overall
- The advantage is strongest in **regression** (85.5%) and **time series** (100%)
- Classification results are **context-dependent** - dataset characteristics matter more than model choice

This suggests: **ensemble methods provide a probabilistic advantage, not a guarantee** - their benefit varies by task type, dataset, and metric used for evaluation.
