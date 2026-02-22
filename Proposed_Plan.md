# TPSM Project - Proposed Plan

> **Source:** Group leader's tentative proposal + ChatGPT guidance
> **Status:** Draft - not finalized
> **Reference:** [ChatGPT Statistical Modelling Guide](Chat_Logs/ChatGPT-Statistical%20Modelling%20for%20Ensembles.md)

---

## Overview

Compare ensemble models vs single models to validate the statement:

> "Ensemble models perform better than single models in many prediction tasks."

---

## Proposed Model Structure

| Task Type | Ensemble Model | Single Model |
|-----------|----------------|--------------|
| Classification | TBD | TBD |
| Regression | TBD | TBD |

**Total:** 4 models

---

## Approach

Based on ChatGPT guidance (aligned with LO1-LO6):

### Step 1 – Choose Two Datasets
- **Classification:** Breast Cancer / Heart Disease (Binary → Binomial distribution)
- **Regression:** Housing Price dataset (Continuous → Normal distribution)

### Step 2 – Descriptive Analysis (LO1)
- Show distribution of target variables
- Mention Binomial & Normal distributions

### Step 3 – Train Single Models (LO3, LO4)
- Regression: Linear Regression
- Classification: Logistic Regression

### Step 4 – Train Ensemble Models
- Random Forest (for both tasks)
- Explain variance reduction: Var(X̄) = σ²/n

### Step 5 – K-Fold Cross Validation (K = 5 or 10)
- Collect fold-wise scores
- Compute differences: dᵢ = Ensembleᵢ - Singleᵢ

### Step 6 – Hypothesis Testing (LO2)
- H₀: μd = 0 (no difference)
- H₁: μd > 0 (ensemble better)
- Paired t-test: t = d̄ / (sd / √K)
- Decision: if p < 0.05, reject H₀

### Step 7 – Interpretation
- Use statistical language for conclusion

### Step 8 – Conclusion
- Summarize results for both tasks

---

## Notes

- Plan is tentative and subject to change
- Need to finalize dataset selection
- Need to finalize specific model choices

---

## References

- [Group Context](Group_Context_and_Questions.md)
- [Q&A Knowledge Base](QA_Knowledge_Base.md)
