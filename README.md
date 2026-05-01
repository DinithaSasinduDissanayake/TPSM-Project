# Ensemble Models vs Single Models

> A statistical analysis comparing ensemble and single model performance on prediction tasks

[![R](https://img.shields.io/badge/R-4.x-blue.svg)](https://www.r-project.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## Phase 1 Recovery Status

Start with [FINAL_PROJECT_MAP.md](FINAL_PROJECT_MAP.md).

The current stable foundation is the recovered Python generator in
`code/python/tpsm/` and the recovered no-time-series evidence CSV:

```text
outputs/archive/legacy/py_full_no_timeseries_probe/20260421T231947/analysis_ready_pairwise.csv
```

That CSV contains 13,950 paired comparisons across 19 classification/regression
datasets. Time series is excluded from the final project direction.

`final_outputs/` is a small later subset and should not be treated as the real
project foundation for Phase 1.

Safe tiny demo command:

```bash
.venv/bin/python -m code.python.tpsm.main --config config/generated/demo_no_timeseries_tiny.yaml --output-dir outputs/active/demo_no_timeseries_tiny_live
```

Do not run the full 19-dataset benchmark for a live demo.

## Overview

This project investigates the hypothesis: **"Ensemble models perform better than single models in many prediction tasks."**

### Final outputs

The cleaned CSVs used for the final analysis are in `final_outputs/`:
- `final_cleaned_pairwise_differences.csv`
- `final_cleaned_model_runs.csv`
- `final_summary.csv`

These files contain the final cleaned comparison data for the project scope used in the write-up.

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

## Usage

### Basic Run

```bash
Rscript scripts/main.R
```

This runs the full pipeline with default settings:
- All tasks (classification, regression, timeseries)
- Sequential processing (1 worker)
- Output to `outputs/` directory

### CLI Options

| Flag | Description | Example |
|------|-------------|---------|
| `--fast` | Enable fast mode (auto-detects CPU cores) | `--fast` |
| `--workers <N>` | Set specific number of parallel workers | `--workers 8` |
| `--task <name>` | Run only specific task (classification/regression/timeseries) | `--task classification` |
| `--output-dir <path>` | Custom output directory | `--output-dir my_results` |
| `--config <path>` | Use custom config file | `--config config/quick_test.yaml` |

### Fast Mode

The `--fast` flag enables dataset-level parallelism for faster execution:

**When to use:**
- Running with many datasets (10+ datasets)
- Production runs with full dataset suite (25 datasets)

**Performance expectations:**
- With 25 datasets: **6-10x speedup** (20 min → 2-3 min)
- With 3 datasets: Slower due to parallelization overhead

**Worker count:**
- Auto-detects CPU cores and sets workers to `cores - 2`
- Can be overridden with `--workers <N>` flag

**Reproducibility:**
- Fast mode produces identical results to sequential mode
- Verified across classification, regression, and timeseries tasks

### Examples

**Run all datasets in fast mode:**
```bash
Rscript scripts/main.R --fast
```

**Run only classification task with 4 workers:**
```bash
Rscript scripts/main.R --task classification --workers 4
```

**Run with custom config:**
```bash
Rscript scripts/main.R --config config/quick_test.yaml
```

**Run the cheapest end-to-end validation path:**
```bash
Rscript scripts/main.R --config config/minimal_validation.yaml --output-dir .runtime/minimal_validation
Rscript scripts/combine_outputs.R .runtime/minimal_validation
Rscript scripts/analysis_statistical.R .runtime/minimal_validation/combined_pairwise_differences.csv .runtime/minimal_validation/analysis
```

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
- **future/furrr** — parallel processing (for `--fast` mode)
- **filelock** — safe concurrent file operations

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
