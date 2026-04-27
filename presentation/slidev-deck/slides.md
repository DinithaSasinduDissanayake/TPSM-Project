---
theme: default
title: Ensemble Models vs Single Models
info: |
  TPSM project presentation recreated in Slidev from the existing final deck.
class: tpsm-deck
drawings:
  persist: false
transition: slide-left
mdc: true
fonts:
  sans: Inter
  mono: JetBrains Mono
layout: cover
---

# Ensemble Models vs Single Models

<div class="cover-subtitle">
  How we generated evidence and analyzed it
</div>

<div class="cover-tags">
  <span>Classification</span>
  <span>Regression</span>
  <span>Paired comparisons</span>
</div>

---
layout: section
---

# Problem Statement

<div class="big-question">Do ensembles consistently beat single models?</div>

<div class="question-grid">
  <div>Does the answer change by dataset?</div>
  <div>Does the answer change by metric?</div>
  <div>Can the final claim survive warnings and failures?</div>
</div>

---
layout: statement
---

# Objectives

<div class="objective-list">
  <div><strong>Build fair comparisons</strong><span>Same split, same dataset, same metric.</span></div>
  <div><strong>Measure paired differences</strong><span>Convert model outputs into directly comparable rows.</span></div>
  <div><strong>Analyze from multiple views</strong><span>Task, dataset, metric, and model-pair perspectives.</span></div>
  <div><strong>Reach a defendable conclusion</strong><span>Keep the claim conditional where evidence is mixed.</span></div>
</div>

---
layout: image
image: /images/diagrams/data_generation_hierarchy.png
---

# Data Collection

---
layout: image
image: /images/diagrams/data_generation_flow.png
---

# Data Collection

---
layout: image
image: /images/diagrams/data_generation_artifacts.png
---

# Data Collection

---
layout: image
image: /images/diagrams/paired_comparison_logic.png
---

# Data Preprocessing

<div class="caption-row">
  <span>Matched comparisons from the same split</span>
  <span>Raw outputs become analysis-ready rows</span>
</div>

---
layout: image
image: /images/diagrams/analysis_question_map.png
---

# Descriptive Analysis

---
layout: image
image: /images/diagrams/analysis_flow.png
---

# Descriptive Analysis

---
layout: image
image: /images/charts/analysis_winrate_by_task.png
---

# Descriptive Analysis

---
layout: image
image: /images/charts/analysis_dataset_winrate_extremes.png
---

# Descriptive Analysis

---
layout: image
image: /images/r_analysis_charts/plots/boxplot_by_metric.png
---

# Descriptive Analysis

---
layout: image
image: /images/r_analysis_charts/plots/histogram_differences.png
---

# Descriptive Analysis

---
layout: image
image: /images/diagrams/paired_comparison_logic.png
---

# Inferential Analysis

---
layout: image
image: /images/charts/analysis_winrate_by_task_metric.png
---

# Inferential Analysis

---
layout: image
image: /images/r_analysis_charts/plots/winrate_by_dataset_metric.png
---

# Inferential Analysis

---
layout: image
image: /images/charts/analysis_model_pair_winrate.png
---

# Predictive Model

---
layout: image
image: /images/r_analysis_charts/plots/heatmap_model_pair.png
---

# Predictive Model

---
layout: image
image: /images/diagrams/final_message_map.png
---

# Results

---
layout: two-images
imageA: /images/charts/analysis_winrate_by_task.png
imageB: /images/charts/analysis_winrate_by_task_metric.png
---

# Results

---
layout: image
image: /images/charts/analysis_dataset_winrate_extremes.png
---

# Results

---
layout: image
image: /images/charts/analysis_model_pair_winrate.png
---

# Results

---
layout: image
image: /images/diagrams/final_message_map.png
---

# Final Decision

<div class="decision-strip">
  <span>Ensembles often help, but not always</span>
  <span>Final claim must stay conditional</span>
  <span>Warnings and mixed datasets matter</span>
</div>

---
layout: image
image: /images/charts/warnings_by_dataset_latest_run.png
---

# Final Decision

---
layout: end
---

# Conclusion

<div class="conclusion-grid">
  <div>We built fair comparisons across many datasets.</div>
  <div>We stored raw results and paired differences.</div>
  <div>We analyzed results visually and statistically.</div>
  <div>Final conclusion depends on task, dataset, and metric.</div>
</div>
