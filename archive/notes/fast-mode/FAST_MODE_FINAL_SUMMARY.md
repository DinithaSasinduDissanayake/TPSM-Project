# Final Analysis Summary

**Project:** Ensemble Models vs Single Models  
**Module Fit:** Statistical analysis format aligned with descriptive analysis, hypothesis testing, and interpretation
**Date:** 2026-03-03

---

## 1. Research Problem

This project examines whether ensemble models perform better than single models in prediction tasks.

The main focus is not only prediction accuracy, but also the interpretation of performance differences across:
- classification
- regression
- time series

---

## 2. Objective

To compare ensemble and single models using a statistical analysis approach that supports:
- descriptive analysis of results
- formal hypothesis testing
- interpretation of model performance differences

---

## 3. Data and Comparison Structure

The study produced performance comparisons across multiple datasets and model pairs.

### Task Coverage

| Task | Datasets | Model Type |
|------|----------|------------|
| Classification | 2 | Single vs Ensemble |
| Regression | 2 | Single vs Ensemble |
| Time Series | 2 | Single vs Ensemble |

### Total Comparisons

| Category | Value |
|----------|-------|
| Total model comparisons | 3,160 |
| Classification comparisons | 1,800 |
| Regression comparisons | 1,200 |
| Time series comparisons | 160 |

---

## 4. Descriptive Analysis

### Overall Pattern

| Metric | Result |
|--------|--------|
| Ensemble win rate overall | 68.7% |
| Mean difference | 501.03 |

### By Task Type

| Task | Comparisons | Ensemble Win Rate |
|------|-------------|-------------------|
| Regression | 1,200 | 85.5% |
| Classification | 1,800 | 54.7% |
| Time Series | 160 | Historical aggregate only |

### Key Observations

1. Regression showed the strongest and most consistent advantage for ensemble methods.
2. Classification results were mixed and depended on the dataset.
3. Time series outcomes were not universal and should be interpreted by dataset rather than as a single rule.

---

## 5. Hypothesis Testing

### Hypotheses

- **H₀:** There is no difference between ensemble models and single models.
- **H₁:** There is a significant difference between ensemble models and single models.

### Test Used

- Paired comparison of performance differences
- Significance level: **α = 0.05**

### Decision Rule

- If **p < 0.05**, reject H₀
- If **p ≥ 0.05**, fail to reject H₀

### Interpretation of the Result

The results indicate that ensemble models are **not universally superior**, but they do show a measurable advantage in many comparisons, especially in regression.

---

## 6. Detailed Interpretation

### Regression

Gradient boosting regressor performed strongly against the single-model baselines.

| Pairing | Win Rate |
|---------|----------|
| decision_tree_regressor → gradient_boosting_regressor | 100% |
| svr → gradient_boosting_regressor | 82.8% |
| linear_regression → gradient_boosting_regressor | 73.8% |

**Interpretation:**  
For regression, ensemble learning gave the clearest benefit. This supports the idea that ensemble methods can reduce error more effectively than single models on continuous prediction tasks.

### Classification

Classification was more dataset-dependent.

| Pairing | Win Rate |
|---------|----------|
| naive_bayes → gradient_boosting | 61.7% |
| logistic_regression → gradient_boosting | 48.7% |

**Interpretation:**  
The advantage of ensembles in classification is weaker and depends on the dataset structure. This is consistent with the module emphasis on interpretation rather than only model accuracy.

### Time Series

Time series results were mixed.

**Interpretation:**  
The time series findings should not be presented as a single universal conclusion. They are better treated as dataset-specific outcomes.

---

## 7. Conclusion

The study partially supports the idea that ensemble models perform better than single models.

### Final Conclusion

- Ensemble methods performed best overall in regression.
- Classification showed mixed results.
- Time series results were dataset-dependent.

### Final Takeaway

The strongest conclusion is that ensemble methods provide a **statistical advantage in many cases**, but not in every case. Therefore, the correct interpretation is:

> ensemble models are often better, but their benefit depends on the task type, dataset, and metric used.

---

## 8. Limitations

- The results depend on the selected datasets.
- Different metrics can change the interpretation.
- Time series performance is especially sensitive to dataset characteristics.
- The project emphasizes interpretation, so predictive accuracy alone should not be treated as the only success criterion.

---

## 9. Recommended Final Presentation Flow

1. Research problem
2. Objective
3. Data summary
4. Descriptive analysis
5. Hypothesis testing
6. Interpretation of results
7. Conclusion

