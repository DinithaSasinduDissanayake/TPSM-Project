# Methodology

> Our approach to validate: "Ensemble models perform better than single models in many prediction tasks."

---

## Overview

We compare ensemble models against single models across classification, regression, and time series tasks using a meta-level approach. The key insight: we generate performance differences from multiple model families, tasks, datasets, and cross-validation splits to build a sample of 300+ comparisons.

---

## Hypotheses

- **H₀:** μd = 0 (no difference between ensemble and single models)
- **H₁:** μd ≠ 0 (significant difference exists)

---

## Population & Sample (Meta-Level)

### Population
The true distribution of performance differences between ensemble models and single models across all possible prediction tasks.

### Sample
Performance differences (d values) generated from:
- Multiple tasks (classification, regression, time series)
- Multiple datasets per task
- Multiple model families (single vs ensemble)
- Multiple cross-validation splits

### Sample Size Calculation
```
N = tasks × datasets × model_pairs × folds × repeats

Example:
- 3 tasks × 2 datasets × 3 model_pairs × 10 folds = 180 differences
- With 5 repeats: 180 × 5 = 900 differences ✓
```

---

## Model Structure

### Classification
| Category | Models |
|----------|--------|
| Single | Logistic Regression, Decision Tree, Naive Bayes |
| Ensemble | Gradient Boosting (gbm), Random Forest |

### Regression
| Category | Models |
|----------|--------|
| Single | Linear Regression, Decision Tree Regressor, SVR |
| Ensemble | Gradient Boosting Regressor (gbm) |

### Time Series
| Category | Models |
|----------|--------|
| Single | ARIMA, Exponential Smoothing |
| Ensemble | GBM with Lag Features |

**Total model pairs:** 3 per task type (classification: LR→GB, DT→RF, NB→GB; regression: LR→GBR, DT→GBR, SVR→GBR; timeseries: ARIMA→GBM_lag, ES→GBM_lag)

---

## Approach

### Step 1 – Dataset Selection

> "To get a good result from the data at least you should be having around 300 observations."
>
> — Mr. Samadhi Chathuranga Rathnayake
> Week 1 Assignment Briefing

> "Is it okay to use two data sets? Completely fine. You can even go with multiple data sets. That's completely allowed."
>
> — Mr. Samadhi Chathuranga Rathnayake
> Week 1 Assignment Briefing

**Selection Criteria:**
- Minimum 300 observations per dataset
- Binary target (classification) or continuous target (regression)
- Mix of numeric and categorical features
- From Kaggle or UCI Machine Learning Repository

**Recommended Datasets:**

| Task | Dataset | Source | Rows |
|------|---------|--------|------|
| Classification | Heart Disease | UCI | 303 |
| Classification | Breast Cancer | UCI | 569 |
| Regression | Medical Insurance | Kaggle | 1,338 |
| Regression | Housing Prices (UK) | Kaggle | 545 |
| Time Series | Melbourne Temperature | UCI | 3,650 |
| Time Series | Electric Production | GitHub | 397 |

### Step 2 – Descriptive Analysis
- Analyze target variable distributions
- Check for missing values, outliers
- Document class balance (classification)
- Visualize distributions

### Step 3 – Train Multiple Single Models
- Regression: Linear Regression, Decision Tree, SVR
- Classification: Logistic Regression, Decision Tree, KNN, Naive Bayes
- Time Series: ARIMA, Exponential Smoothing

### Step 4 – Train Multiple Ensemble Models
- Random Forest, Gradient Boosting, AdaBoost, XGBoost
- Document variance reduction principle: Var(X̄) = σ²/n

### Step 5 – Cross-Validation & Comparison
- K-Fold Cross Validation (K = 10)
- Repeated CV (5 repeats) for larger sample
- Compute performance differences: dᵢ = Ensemble_metric - Single_metric
- For accuracy: higher = better
- For RMSE: lower = better

### Step 6 – Hypothesis Testing
- Paired t-test on difference scores
- Significance level: α = 0.05
- Decision rule: if p < 0.05, reject H₀

### Step 7 – Interpretation
- Statistical interpretation of results
- Practical significance assessment
- Effect size reporting

### Step 8 – Conclusion
- Summarize findings across all tasks
- Statement validation

---

## Tools

**Primary:** R

> "I don't restrict you to use the R. You can go with any analysis tool but I recommend you to use the R. R is having the most powerful statistical repositories."
>
> — Mr. Samadhi Chathuranga Rathnayake
> Week 1 Assignment Briefing

### R Packages

| Package | Purpose |
|---------|---------|
| `gbm` | Gradient Boosting (classification and regression) |
| `rpart` | Decision Trees |
| `e1071` | SVR, Naive Bayes |
| `forecast` | Time series (ARIMA, Exponential Smoothing) |
| `jsonlite` | JSON logging |
| `t.test()` | Hypothesis testing (built-in) |
| `tidyverse` | Data manipulation and visualization |

---

## Status

- [x] Dataset selection finalized
- [x] Models trained and evaluated (3,160 comparisons generated)
- [x] Hypothesis testing completed
- [x] Results documented
- [x] Python pipeline validated and patched after targeted audits

See [python-validation-2026-03-06.md](python-validation-2026-03-06.md) for the current validation record and operational caveats.

---

## Known Limitations

### Python Pipeline Caveats (2026-03-06)
**Severity:** Medium | **Confidence:** 95% | **Status:** Fixed / documented

**Resolved issues:**
- leakage-safe split preprocessing added
- `housing_prices` date handling fixed
- binary coercion bug fixed for classification
- `air_quality` schema mismatch fixed for timeseries
- `decision_tree vs adaboost` replaced with `decision_tree vs random_forest`

**Remaining caveats:**
- `metro_traffic` and `household_power` are very expensive with rolling-origin ARIMA
- `MAPE` is not reliable on low-target time series datasets such as `household_power` and `air_quality`

**Operational controls now in shared config:**
- `metro_traffic` and `household_power` use lighter time-series validation settings
- current overrides: `splits_override=3`, `max_ts_train_rows=12000`, `arima_max_order=3`
- pairwise rows now carry `MAPE`/`SMAPE` reliability notes when low-target risk is detected

### Ordinal Encoding Bias (H1)
**Severity:** Medium | **Confidence:** 85% | **Status:** Documented (not fixed)

**Problem:** Categorical features are encoded as integers (1, 2, 3, ...) using alphabetical ordering. This imposes an artificial ordinal relationship on nominal data.

**Example:** If a feature has values `["red", "green", "blue"]`, they are encoded as `[3, 1, 2]`, implying `green < blue < red`.

**Impact:**
- **Hurts linear models:** Logistic regression, linear regression, SVR interpret these as continuous ordinal values and fit linear relationships to arbitrary orderings
- **Helps tree-based models:** Gradient boosting, decision trees can split on any threshold, so ordinal vs nominal encoding barely matters
- **Systematic bias:** May inflate ensemble win rates (tree-based) vs single models (linear models)

**Why not fixed:**
- One-hot encoding would add significant complexity (feature explosion for high-cardinality categorical features)
- Time constraints for student project scope
- Focus is on ensemble vs single model comparison, not optimal encoding strategies

**Recommendation for future work:**
- Implement one-hot encoding for linear models only
- Use ordinal encoding for tree-based models (current behavior)
- This would remove the systematic bias while maintaining efficiency

**Affected comparisons:**
- Logistic Regression vs Gradient Boosting
- Linear Regression vs Gradient Boosting Regressor
- SVR vs Gradient Boosting Regressor
