# Methodology

> Our approach to validate: "Ensemble models perform better than single models in many prediction tasks."

---

## Overview

We compare ensemble models against single models across classification and regression tasks to test whether ensemble methods consistently outperform individual models.

---

## Hypotheses

- **H₀:** Ensemble models do not improve performance over single models (μd = 0)
- **H₁:** Ensemble models improve performance over single models (μd > 0)

---

## Model Structure

| Task Type | Ensemble Model | Single Model |
|-----------|----------------|--------------|
| Classification | Random Forest | Logistic Regression |
| Regression | Random Forest Regressor | Linear Regression |

**Total:** 4 models compared

---

## Approach (8 Steps)

### Step 1 – Dataset Selection
- **Classification:** Breast Cancer / Heart Disease (binary target → Binomial distribution)
- **Regression:** Housing Price dataset (continuous target → Normal distribution)

### Step 2 – Descriptive Analysis
- Analyze target variable distributions
- Document Binomial and Normal distribution characteristics

### Step 3 – Train Single Models
- Linear Regression (regression task)
- Logistic Regression (classification task)

### Step 4 – Train Ensemble Models
- Random Forest (both tasks)
- Document variance reduction principle: Var(X̄) = σ²/n

### Step 5 – Cross-Validation
- K-Fold Cross Validation (K = 5 or 10)
- Collect fold-wise performance scores
- Compute differences: dᵢ = Ensembleᵢ - Singleᵢ

### Step 6 – Hypothesis Testing
- Paired t-test: t = d̄ / (sd / √K)
- Significance level: α = 0.05
- Decision rule: if p < 0.05, reject H₀

### Step 7 – Interpretation
- Statistical interpretation of results
- Practical significance assessment

### Step 8 – Conclusion
- Summarize findings for both tasks
- Statement validation

---

## Tools

- Python (scikit-learn, pandas, numpy)
- Jupyter Notebooks
- Statistical analysis (scipy.stats)

---

## Status

- [ ] Dataset selection finalized
- [ ] Models trained and evaluated
- [ ] Hypothesis testing completed
- [ ] Results documented
