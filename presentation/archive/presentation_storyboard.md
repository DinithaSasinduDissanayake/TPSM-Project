# Title Slide

**Visual:** title slide

**Use this as:** team-teach version under lecturer structure

**Main points:**
- Ensemble Models vs Single Models
- How we generated evidence and analyzed it
- Classification and regression focus
- Deck explains both process and findings

**Say:**
- This project tests whether ensemble models really outperform single models.
- We compare them fairly across many datasets.

---

# Problem Statement

**Visual:** simple question slide

**Main points:**
- Do ensembles consistently beat single models?
- Does result change by dataset?
- Does result change by metric?
- Can we defend answer with fair evidence?

**Say:**
- Problem is not “which model is fancy.”
- Problem is whether ensemble advantage is real and reliable.

---

# Objectives

**Visual:** simple objective slide

**Main points:**
- Build fair comparisons
- Measure paired differences
- Analyze results from multiple views
- Reach defendable conclusion
- Teach team what pipeline is doing

**Say:**
- Objectives are to generate evidence, analyze it, and explain it clearly.
- We need both process and findings.

---

# Data Collection

**Visuals:**

![[diagrams/data_generation_hierarchy.png]]

![[diagrams/data_generation_flow.png]]

![[diagrams/data_generation_artifacts.png]]

**Main points:**
- Start from task type, datasets, and model pairs
- Load raw data and organize experiment structure
- Create repeated splits for fair comparison
- Train single and ensemble models under same conditions
- Write final run artifacts for later analysis

**Say:**
- This section explains where data comes from and how one run is organized.
- Hierarchy shows structure. Flow shows sequence. Artifact view shows what the run produces.
- This is team-teach slide: what system does before any conclusion.

---

# Data Preprocessing

**Visuals:**

![[diagrams/paired_comparison_logic.png]]

**Main points:**
- Prepare datasets before training
- Build matched comparisons from same split
- Convert raw outputs into analysis-ready comparison rows
- Keep comparison fair by matching same dataset and same split

**Say:**
- Preprocessing here includes cleaning, preparing, splitting, and shaping outputs for analysis.
- Important output is paired comparison data.
- This is bridge between raw runs and statistical analysis.

---

# Descriptive Analysis

**Visuals:**

![[diagrams/analysis_question_map.png]]

![[diagrams/analysis_flow.png]]

![[charts/analysis_winrate_by_task.png]]

![[charts/analysis_dataset_winrate_extremes.png]]

![[r_analysis_charts/plots/boxplot_by_metric.png]]

![[r_analysis_charts/plots/histogram_differences.png]]

**Main points:**
- Summarize results first
- Check overall task-level pattern
- Check strongest and weakest datasets
- Use analysis questions to guide what summaries matter
- Show distribution of differences, not only averages
- Teach team what patterns appear before formal testing

**Say:**
- Descriptive analysis answers what patterns we see before formal testing.
- This is the first big-picture view.
- Here we describe data, not prove claim yet.

---

# Inferential Analysis

**Visuals:**

![[diagrams/paired_comparison_logic.png]]

![[charts/analysis_winrate_by_task_metric.png]]

![[r_analysis_charts/plots/winrate_by_dataset_metric.png]]

**Main points:**
- Use paired comparisons from same split
- Test whether observed gains are statistically meaningful
- Compare how evidence changes by metric
- Check whether metric behavior stays consistent across datasets
- Move from pattern-seeing to evidence-strength

**Say:**
- Inferential analysis moves from summary to evidence strength.
- Same split pairing is what makes this statistically valid.
- Team should understand why paired setup matters.

---

# Predictive Model

**Visuals:**

![[charts/analysis_model_pair_winrate.png]]

![[r_analysis_charts/plots/heatmap_model_pair.png]]

**Main points:**
- Compare specific single and ensemble model pairs
- Show which upgrades work best
- Connect performance back to model choice
- Show model-pair behavior across datasets
- Explain practical model selection, not only abstract statistics

**Say:**
- This slide focuses on models themselves.
- Not every ensemble upgrade gives same benefit.

---

# Results

**Visuals:**

![[diagrams/final_message_map.png]]

![[charts/analysis_winrate_by_task.png]]

![[charts/analysis_winrate_by_task_metric.png]]

![[charts/analysis_model_pair_winrate.png]]

![[charts/analysis_dataset_winrate_extremes.png]]

![[r_analysis_charts/plots/winrate_by_dataset_metric.png]]

**Main points:**
- Regression often favors ensembles
- Classification is more dataset-dependent
- Model pair and metric both affect outcome
- Results should be shown from more than one angle
- Different visuals reveal different parts of same story
- This section gathers main evidence team should remember

**Say:**
- Results should be presented as patterns, not as one universal rule.
- This is summary of evidence, not code pipeline.

---

# Final Decision

**Visuals:**

![[diagrams/final_message_map.png]]

![[charts/analysis_dataset_winrate_extremes.png]]

![[charts/analysis_model_pair_winrate.png]]

![[charts/warnings_by_dataset_latest_run.png]]

**Main points:**
- Ensembles often help, but not always
- Final claim must stay conditional
- Failures, warnings, and mixed datasets matter
- Caveat visuals should appear near final decision, not hidden
- Final statement must match evidence quality

**Say:**
- Final decision is balanced.
- We support ensemble advantage in many cases, not all cases.

---

# Conclusion

**Visual:** clean closing slide

**Main points:**
- We built fair comparisons across many datasets
- We stored both raw results and paired differences
- We analyzed results visually and statistically
- Final conclusion depends on task, dataset, and metric
- Team can now explain pipeline and findings in same story

**Say:**
- Project is evidence-driven.
- Strong conclusion is specific, not exaggerated.

## Current Image Set

- `docs/diagrams/data_generation_hierarchy.png`
- `docs/diagrams/data_generation_flow.png`
- `docs/diagrams/data_generation_artifacts.png`
- `docs/diagrams/analysis_question_map.png`
- `docs/diagrams/analysis_flow.png`
- `docs/diagrams/paired_comparison_logic.png`
- `docs/diagrams/final_message_map.png`
- `docs/charts/analysis_winrate_by_task.png`
- `docs/charts/analysis_dataset_winrate_extremes.png`
- `docs/charts/analysis_model_pair_winrate.png`
- `docs/charts/analysis_winrate_by_task_metric.png`
- `docs/charts/warnings_by_dataset_latest_run.png`
- `docs/r_analysis_charts/plots/boxplot_by_metric.png`
- `docs/r_analysis_charts/plots/heatmap_model_pair.png`
- `docs/r_analysis_charts/plots/histogram_differences.png`
- `docs/r_analysis_charts/plots/winrate_by_dataset_metric.png`
