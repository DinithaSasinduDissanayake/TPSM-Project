# Ensemble Models vs Single Models

> A statistical analysis comparing ensemble and single model performance on prediction tasks

[![R](https://img.shields.io/badge/R-4.x-blue.svg)](https://www.r-project.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## Overview

This project investigates the hypothesis: **"Ensemble models perform better than single models in many prediction tasks."**

We compare ensemble methods (Random Forest) against single models (Linear/Logistic Regression) across classification and regression tasks using formal statistical hypothesis testing.

Current validation status for the Python pipeline is documented in [docs/python-validation-2026-03-06.md](docs/python-validation-2026-03-06.md). Current overall confidence after targeted audits and fixes is `98/100`.

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

---

## Technical Approach

### Models Compared

| Task | Single Model | Ensemble Model |
|------|--------------|----------------|
| Classification | Logistic Regression, Decision Tree, Naive Bayes | Gradient Boosting, Random Forest |
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
| Time Series | 160 | Historical aggregate only |
| Regression | 1,200 | **85.5%** |
| Classification | 1,800 | **54.7%** |
| **Overall** | **3,160** | **68.7%** |

### Key Insights

1. **Regression**: Gradient boosting regressor is a strong and stable ensemble baseline after configuration fixes.
2. **Classification**: Results remain dataset-dependent; the default tree ensemble benchmark was changed from AdaBoost to Random Forest because AdaBoost was unstable on multiclass datasets.
3. **Time Series**: Results are mixed by dataset. ARIMA wins on some series, while `gbm_lag` wins on others. Heavy ARIMA datasets now use lighter dataset-specific controls for validation.
4. **Metric interpretation matters**: `MAPE` is unreliable on several low-target time series datasets; prefer RMSE, MAE, and SMAPE there, and treat `MAPE` notes in pairwise outputs as reliability warnings.

### Best Model Pairings

| Pairing | Win Rate |
|---------|----------|
| decision_tree_regressor → gradient_boosting_regressor | 100% |
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
