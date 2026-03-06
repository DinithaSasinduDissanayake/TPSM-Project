# Q&A Log

> Resolved and open questions from lectures and discussions

---

## Resolved Questions

### Q0: Is the Python pipeline ready for controlled production?
**Answer:** YES, with caveats.

Current assessment after targeted audits:
- regression pipeline is clean
- classification pipeline is clean after replacing `decision_tree -> adaboost` with `decision_tree -> random_forest`
- timeseries pipeline is clean after fixing the `air_quality` schema mismatch
- overall Python pipeline confidence is currently `98/100`

Main caveats:
- `metro_traffic` and `household_power` are operationally expensive with ARIMA
- `MAPE` is unreliable on some low-target timeseries datasets

Current mitigations:
- shared config now uses lighter controls for heavy time-series datasets
- pairwise outputs carry `MAPE` / `SMAPE` reliability notes when low-target risk is detected

See [python-validation-2026-03-06.md](python-validation-2026-03-06.md).

### Q1: What is expected for the project?
**Answer:** Justify whether the selected statement is correct or wrong using:
- Descriptive analytics
- Hypothesis testing
- Predictive modeling

*Source: Week 5 Lecture (2026-02-21)*

---

### Q2: Do we need formal hypothesis testing?
**Answer:** YES — hypothesis testing is required.

*Source: Week 5 Lecture (2026-02-21)*

---

### Q3: Are we restricted to R?
**Answer:** NO — any tool allowed. Lecturer wants to see how you reach your conclusion.

*Source: Week 5 Lecture (2026-02-21)*

---

### Q4: What is mid-evaluation format?
**Answer:**
- Viva (5-10 mins)
- No report, no presentation
- Random questions to any team member
- Common group mark
- Don't bring laptops

*Source: Week 5 Lecture (2026-02-21)*

---

### Q5: What if we use black-box models?
**Answer:** Allowed, but must interpret using feature importance, LIME, or SHAP.

*Source: Week 5 Lecture (2026-02-21)*

---

### Q6: Is focus on accuracy or interpretation?
**Answer:** INTERPRETATION — not prediction accuracy.

*Source: Week 5 Lecture (2026-02-21)*

---

## Open Questions

### Q1: Should we use 1 dataset or multiple?
**Status:** Pending — Sandun to ask lecturer

---

### Q2: What if results are mixed?
Scenario: One experiment supports ensemble, another favors single model.

**Status:** Need clarification

---

### Q3: When will templates be shared?
Presentation templates for final (70%) not yet released.

**Status:** Waiting
