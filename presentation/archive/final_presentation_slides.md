---
marp: true
theme: default
paginate: true
backgroundColor: "#ffffff"
style: |
  section {
    font-family: Arial, sans-serif;
    color: #111;
    padding: 40px 56px;
  }
  h1 {
    font-size: 2.0rem;
    margin-bottom: 0.35rem;
  }
  h2 {
    font-size: 1.2rem;
    margin-top: 0.2rem;
    margin-bottom: 0.4rem;
  }
  p, li {
    font-size: 0.95rem;
    line-height: 1.3;
  }
  img {
    background: white;
  }
---

# Title Slide

## Ensemble Models vs Single Models

- Fair comparisons across many datasets
- Focus on classification and regression
- Goal: evidence, not assumption

---

# Problem Statement

- Do ensemble models consistently beat single models?
- Does result change by dataset?
- Does result change by metric?
- Can we defend answer with paired evidence?

---

# Objectives

- Build fair, matched comparisons
- Store raw results and paired differences
- Summarize patterns from several angles
- Reach defensible conclusion without overclaiming

---

# Statistical Inference Framing

- `Target population`: single-model vs ensemble-model comparisons for tabular supervised learning under comparable evaluation settings
- `Study population`: classification and regression benchmark datasets, predefined model pairs, and predefined metrics used in this project
- `Sample`: observed rows in `pairwise_differences.csv`
- One row = one dataset, one split, one metric, one model-pair comparison

---

# Sampling Logic

- Dataset selection follows `convenience sampling`
- Reason: datasets were predefined and taken from easily accessible public benchmark sources
- Model pairs were `purposively selected` as part of experiment design
- Restriction to classification and regression is `scope restriction`, not sampling method
- Therefore, conclusions should stay conditional and not claim all ML problems

---

# Data Collection

![h:230](./diagrams/data_generation_hierarchy.png)

![h:230](./diagrams/data_generation_flow.png)

- Experiment organized by task type, dataset, model pair, and split

---

# Data Preprocessing

![w:980](./diagrams/paired_comparison_logic.png)

- Same dataset + same split -> matched model comparison row
- Output becomes analysis-ready paired differences

---

# Descriptive Analysis

![h:220](./diagrams/analysis_flow.png)

![h:240](./charts/analysis_winrate_by_task.png)

- First ask: where do ensembles win most often?

---

# Inferential Analysis

![h:430](./charts/analysis_winrate_by_task_metric.png)

- Paired split structure supports formal significance testing
- Metric view shows whether gains stay stable across measures

---

# Predictive Model

![h:430](./charts/analysis_model_pair_winrate.png)

- Compare concrete single -> ensemble upgrades
- Not every ensemble upgrade gives same value

---

# Results

![h:430](./charts/analysis_dataset_winrate_extremes.png)

- Best and worst datasets show effect is not universal

---

# Final Decision

![h:220](./charts/analysis_winrate_by_task.png)

![h:220](./charts/analysis_model_pair_winrate.png)

- Ensembles usually help in classification and regression
- Final claim must stay conditional on dataset and metric

---

# Conclusion

- Fair pipeline produced both raw runs and paired differences
- Ensembles show strong overall advantage in classification and regression
- Strength of that advantage still depends on dataset, metric, and model pair
