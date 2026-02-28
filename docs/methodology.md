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
| Single | Logistic Regression, Decision Tree, KNN, Naive Bayes |
| Ensemble | Random Forest, Gradient Boosting, AdaBoost, XGBoost |

### Regression
| Category | Models |
|----------|--------|
| Single | Linear Regression, Decision Tree, SVR |
| Ensemble | Random Forest, Gradient Boosting, AdaBoost |

### Time Series
| Category | Models |
|----------|--------|
| Single | ARIMA, Exponential Smoothing |
| Ensemble | Random Forest (with lag features), XGBoost |

**Total model pairs:** 3+ per task type

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
| Regression | Housing Prices | Kaggle | 545 |
| Time Series | Melbourne Temp | UCI | 3,650 |

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
| `caret` | Model training and cross-validation |
| `randomForest` | Random Forest ensemble |
| `gbm` | Gradient Boosting |
| `xgboost` | XGBoost |
| `adabag` | AdaBoost |
| `e1071` | SVM, KNN, Naive Bayes |
| `MASS` | Dataset access |
| `mlbench` | Dataset access |
| `forecast` | Time series (ARIMA) |
| `tseries` | ADF test for stationarity |
| `t.test()` | Hypothesis testing (built-in) |
| `tidyverse` | Data manipulation and visualization |

---

## Status

- [ ] Dataset selection finalized
- [ ] Models trained and evaluated
- [ ] Hypothesis testing completed
- [ ] Results documented
