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
    font-size: 2.1rem;
    margin-bottom: 0.4rem;
  }
  p, li {
    font-size: 1rem;
    line-height: 1.35;
  }
  img {
    background: white;
  }
---

# Title Slide

## Ensemble Models vs Single Models

- How we generated evidence and analyzed it
- Classification and regression focus

---

# Problem Statement

- Do ensembles consistently beat single models?
- Does result change by dataset?
- Does result change by metric?

---

# Objectives

- Build fair comparisons
- Measure paired differences
- Analyze results from multiple views
- Reach defendable conclusion

---

# Data Collection

![w:1050](./diagrams/data_generation_hierarchy.png)

---

# Data Collection

![h:560](./diagrams/data_generation_flow.png)

---

# Data Collection

![h:560](./diagrams/data_generation_artifacts.png)

---

# Data Preprocessing

![w:1050](./diagrams/paired_comparison_logic.png)

- Build matched comparisons from same split
- Convert raw outputs into analysis-ready comparison rows

---

# Descriptive Analysis

![w:1050](./diagrams/analysis_question_map.png)

---

# Descriptive Analysis

![h:540](./diagrams/analysis_flow.png)

---

# Descriptive Analysis

![h:530](./charts/analysis_winrate_by_task.png)

---

# Descriptive Analysis

![h:530](./charts/analysis_dataset_winrate_extremes.png)

---

# Descriptive Analysis

![h:510](./r_analysis_charts/plots/boxplot_by_metric.png)

---

# Descriptive Analysis

![h:510](./r_analysis_charts/plots/histogram_differences.png)

---

# Inferential Analysis

![w:1050](./diagrams/paired_comparison_logic.png)

---

# Inferential Analysis

![h:530](./charts/analysis_winrate_by_task_metric.png)

---

# Inferential Analysis

![h:520](./r_analysis_charts/plots/winrate_by_dataset_metric.png)

---

# Predictive Model

![h:520](./charts/analysis_model_pair_winrate.png)

---

# Predictive Model

![h:510](./r_analysis_charts/plots/heatmap_model_pair.png)

---

# Results

![w:1050](./diagrams/final_message_map.png)

---

# Results

![h:500](./charts/analysis_winrate_by_task.png)

![h:240](./charts/analysis_winrate_by_task_metric.png)

---

# Results

![h:500](./charts/analysis_dataset_winrate_extremes.png)

---

# Results

![h:500](./charts/analysis_model_pair_winrate.png)

---

# Final Decision

![w:1050](./diagrams/final_message_map.png)

- Ensembles often help, but not always
- Final claim must stay conditional
- Failures, warnings, and mixed datasets matter

---

# Final Decision

![h:500](./charts/warnings_by_dataset_latest_run.png)

---

# Conclusion

- We built fair comparisons across many datasets
- We stored raw results and paired differences
- We analyzed results visually and statistically
- Final conclusion depends on task, dataset, and metric

