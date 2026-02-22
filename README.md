# Ensemble Models vs Single Models

> A statistical analysis comparing ensemble and single model performance on prediction tasks

[![Python](https://img.shields.io/badge/Python-3.x-blue.svg)](https://www.python.org/)
[![scikit-learn](https://img.shields.io/badge/scikit--learn-1.x-orange.svg)](https://scikit-learn.org/)
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
| Classification | Logistic Regression | Random Forest |
| Regression | Linear Regression | Random Forest Regressor |

### Tools

- **Python** — primary language
- **scikit-learn** — ML models and validation
- **pandas/numpy** — data manipulation
- **scipy.stats** — hypothesis testing
- **Jupyter Notebooks** — documentation

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

*Project in progress — results to be updated*

---

## Team

**The Outliers** — IT3011 Theory and Practices in Statistical Modelling

| Member | Role |
|--------|------|
| Dinitha Sasindu Dissanayake | Member |
| Sithmini Thennakoon | Member |
| [Team Member] | Leader |
| [Team Member] | Member |

*Sri Lanka Institute of Information Technology (SLIIT)*

---

## Course Information

- **Module:** IT3011 — Theory and Practices in Statistical Modelling
- **Semester:** Y3S2 (Jan–June 2026)
- **Assignment:** Group Project (15% of module)
