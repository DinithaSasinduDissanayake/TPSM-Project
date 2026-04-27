# Ensemble Models vs Single Models

TPSM project for comparing ensemble models against single models across classification, regression, and time-series prediction tasks.

Main question:

> Do ensemble models consistently outperform single models, or does the advantage depend on dataset, task, and metric?

## Repo Map

Read this section first. Folder names match how the project is meant to be used.

```text
code/          runnable Python/R/tools
config/        production/smoke/debug/generated configs
data/          datasets used by the pipelines
outputs/       active outputs plus archived runs
docs/          report, methodology, validation, figures
presentation/  browser presentation versions
logs/          archived logs
archive/       old notes, old decks, scratch files
```

Important deliverables:

```text
docs/report/                         research reports
docs/methodology/                    methodology and requirements
docs/validation/                     validation notes
docs/figures/                        generated charts and diagrams
presentation/browser-deck-shadcn/    main future-facing browser deck
presentation/slidev-deck/            Slidev browser deck experiment
outputs/active/                      new runs
outputs/archive/                     old complete runs
```

## Python Pipeline

Run a small smoke test:

```bash
python -m code.python.tpsm.main --config config/smoke/mini_smoke.yaml --output-dir outputs/active/python
```

Run the full production config:

```bash
python -m code.python.tpsm.main --config config/production/datasets.yaml --output-dir outputs/active/python
```

Resume a run:

```bash
python -m code.python.tpsm.main --resume-run outputs/active/python/<run-id>
```

Python output files:

```text
model_runs.csv
pairwise_differences.csv
analysis_ready_pairwise.csv
run_manifest.json
run_log.txt
warnings_report.json
failed_datasets.csv
state/run_state.json
```

## R Pipeline

Run a small smoke test:

```bash
Rscript code/r/main.R --config config/smoke/mini_smoke.yaml --output-dir outputs/active/r
```

Run the full production config:

```bash
Rscript code/r/main.R --config config/production/datasets.yaml --output-dir outputs/active/r
```

R output files:

```text
model_runs.csv
pairwise_differences.csv
run_manifest.json
run_log.txt
warnings_report.json
```

## GUI

Start the local Python runner UI:

```bash
python -m code.python.tpsm.gui --output-root outputs/active/gui_runs
```

Or use the launcher:

```bash
./code/tools/launch_tpsm_gui.sh
```

Open the GUI page:

```bash
./code/tools/open_tpsm_gui.sh
```

Default URL:

```text
http://127.0.0.1:8787
```

GUI runs are Python runs stored under:

```text
outputs/active/gui_runs/
```

## Output Archive Behavior

New output roots:

```text
outputs/active/python
outputs/active/r
outputs/active/gui_runs
```

Archive roots:

```text
outputs/archive/python
outputs/archive/r
outputs/archive/gui_runs
```

When a new complete run finishes, old complete runs in the same active output root are moved to the matching archive folder.

Incomplete, paused, stopped, or failed runs stay in `outputs/active/` so they can be inspected or resumed.

Old pre-reorganization outputs live in:

```text
outputs/archive/legacy/
```

## Presentation

Main browser deck:

```bash
cd presentation/browser-deck-shadcn
npm install
npm run dev
npm run build
```

Slidev experiment:

```bash
cd presentation/slidev-deck
npm install
npm run dev
npm run build
```

The shadcn browser deck is the preferred direction for future presentation work. The Slidev deck is kept because presenter mode and export tooling may still be useful.

## Validation After Changes

Run path validation first:

```bash
python code/tools/validate_repo_paths.py
```

Run pipeline smoke checks:

```bash
python -m code.python.tpsm.main --config config/smoke/mini_smoke.yaml --output-dir outputs/active/python_validation
Rscript code/r/main.R --config config/smoke/mini_smoke.yaml --output-dir outputs/active/r_validation
```

Run presentation builds:

```bash
cd presentation/browser-deck-shadcn && npm install && npm run build
cd presentation/slidev-deck && npm install && npm run build
```

## Research Summary

Models compared:

| Task | Single Models | Ensemble Models |
| --- | --- | --- |
| Classification | Logistic Regression, Decision Tree, Naive Bayes | Gradient Boosting, Random Forest |
| Regression | Linear Regression, Decision Tree, SVR | Gradient Boosting Regressor |
| Time Series | ARIMA, Exponential Smoothing | GBM with lag features |

Current interpretation:

- Ensembles often help, especially in regression.
- Classification results are more dataset-dependent.
- Time-series results are mixed.
- Metric choice matters, especially for low-target time-series datasets.
- Final claim should stay conditional, not universal.

## Team

The Outliers — IT3011 Theory and Practices in Statistical Modelling

| Member | Role |
| --- | --- |
| Dinitha Sasindu Dissanayake | Member |
| Sithmini Thennakoon | Member |
| Piyumika Hansika | Leader |
| Tharindu Kavinda | Member |

Sri Lanka Institute of Information Technology.
