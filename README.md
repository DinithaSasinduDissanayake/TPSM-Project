# Ensemble Models vs Single Models

> A statistical analysis comparing ensemble and single model performance on prediction tasks

[![R](https://img.shields.io/badge/R-4.x-blue.svg)](https://www.r-project.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## Overview

This project investigates the hypothesis: **"Ensemble models perform better than single models in many prediction tasks."**

We compare ensemble methods (Random Forest) against single models (Linear/Logistic Regression) across classification and regression tasks using formal statistical hypothesis testing.

---

## Research Question

Do ensemble models consistently outperform single models, or does their advantage depend on specific conditions?

### Hypotheses

- **H₀:** Ensemble models do not improve performance over single models (μd = 0)
- **H₁:** Ensemble models improve performance over single models (μd > 0)

---

## Methodology

| Step | Description |
|------|-------------|
| 1 | Dataset selection (classification + regression) |
| 2 | Descriptive analysis of distributions |
| 3 | Train single models (Linear/Logistic Regression) |
| 4 | Train ensemble models (Random Forest) |
| 5 | K-Fold cross-validation (K=5 or 10) |
| 6 | Paired t-test for significance |
| 7 | Interpretation of results |
| 8 | Conclusion |

See [methodology](docs/methodology.md) for detailed approach.

---

## Technical Approach

### Models Compared

| Task | Single Model | Ensemble Model |
|------|--------------|----------------|
| Classification | Logistic Regression, Decision Tree, Naive Bayes | Gradient Boosting, AdaBoost |
| Regression | Linear Regression, Decision Tree, SVR | Gradient Boosting Regressor |
| Time Series | ARIMA, Exponential Smoothing | GBM with Lag Features |

### Tools

- **R** — primary language (recommended by lecturer)
- **gbm** — gradient boosting for classification and regression
- **rpart** — decision trees
- **e1071** — SVR, Naive Bayes
- **forecast** — time series (ARIMA, Exponential Smoothing)
- **tidyverse** — data manipulation and visualization

> "I don't restrict you to use the R. You can go with any analysis tool but I recommend you to use the R. R is having the most powerful statistical repositories."
>
> — Mr. Samadhi Chathuranga Rathnayake
> Week 1 Assignment Briefing

### Statistical Validation

- Paired t-test across K-fold results
- Significance level: α = 0.05
- Focus on interpretation, not just accuracy

---

## Project Structure

```
TPSM-Project/
├── README.md                 ← You are here
├── TEAM_GUIDE.md             ← Start here (for team)
├── docs/
│   ├── methodology.md        ← Detailed approach
│   ├── requirements.md       ← Project requirements
│   └── qa-log.md             ← Questions & answers
├── notebooks/                ← Jupyter notebooks (TBD)
├── data/                     ← Datasets (TBD)
└── Group Assignment/         ← Official documents
```

---

## Key Findings

*Generated 3,160 model comparisons across classification, regression, and time series tasks.*

### Summary Results

| Task | Comparisons | Ensemble Win Rate |
|------|-------------|-------------------|
| Time Series | 160 | **100%** |
| Regression | 1,200 | **85.5%** |
| Classification | 1,800 | **54.7%** |
| **Overall** | **3,160** | **68.7%** |

### Key Insights

1. **Time Series**: GBM with lag features (gbm_lag) dominates traditional methods — 100% win rate
2. **Regression**: Gradient Boosting Regressor outperforms all single models — 85.5% win rate
3. **Classification**: Results vary by dataset; ensembles win 71.7% on breast_cancer but only 37.8% on heart_disease
4. **Best metric for ensembles**: ROC-AUC (65.3% win), R² (91.3% win), RMSE (92.4% win)

### Best Model Pairings

| Pairing | Win Rate |
|---------|----------|
| arima → gbm_lag | 100% |
| decision_tree_regressor → gradient_boosting_regressor | 100% |
| exp_smoothing → gbm_lag | 100% |
| svr → gradient_boosting_regressor | 82.8% |
| linear_regression → gradient_boosting_regressor | 73.8% |

---

## Team

**The Outliers** — IT3011 Theory and Practices in Statistical Modelling

| Member | Role |
|--------|------|
| Dinitha Sasindu Dissanayake | Member |
| Sithmini Thennakoon | Member |
| Piyumika Hansika | Leader |
| Tharindu Kavinda | Member |

*Sri Lanka Institute of Information Technology (SLIIT)*

---

## Course Information

- **Module:** IT3011 — Theory and Practices in Statistical Modelling
- **Semester:** Y3S2 (Jan–June 2026)
- **Assignment:** Group Project (15% of module)
