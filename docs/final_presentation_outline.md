# Final Presentation Outline

Project statement:

> Ensemble models perform better than single models in many prediction tasks.

Purpose: map the completed TPSM analysis into the assignment presentation template. This is an outline only. It is not the slide deck.

Sources used:

- `outputs/final_project_analysis/final_interpretation_summary.md`
- `outputs/final_project_analysis/01_data_understanding/`
- `outputs/final_project_analysis/02_descriptive_summaries/`
- `outputs/final_project_analysis/03_descriptive_plots/`
- `outputs/final_project_analysis/04_hypothesis_testing/`
- `archive/notes/Lessons learned from lectures for project .md`

Template file note: no local `IT3011_Group_Assignment_Template` file was found during search. This outline uses the template section names given in the request.

## Deck Summary

- Proposed slides: 16
- Essential slides: 14
- Optional slides: 2
- Recommended presentation deck: use the 14 essential slides.
- Optional slides can be kept as appendix or viva backup.

---

## Slide 1

**Template section:** Title Slide  
**Slide title:** Testing Whether Ensembles Perform Better Than Single Models  
**Importance:** Essential

**Main message:**  
We tested the statement using many paired classification and regression model comparisons.

**Content bullets:**

- Statement: "Ensemble models perform better than single models in many prediction tasks."
- Scope: classification and regression only
- Time series excluded
- Main evidence: 13,950 paired comparison rows

**Suggested visual/chart/table:**  
Title slide with statement, group name, and scope badges: `Classification`, `Regression`, `No time series`.

**Speaker notes:**  
Open by saying this is not one model accuracy result. It is a repeated comparison study.

**Supporting output/result:**  
`outputs/final_project_analysis/final_interpretation_summary.md`

---

## Slide 2

**Template section:** Group Details  
**Slide title:** Group Members And Contributions  
**Importance:** Essential

**Main message:**  
Show who did what in the group project.

**Content bullets:**

- Group member names
- Student IDs
- Main contribution per member
- Suggested contribution areas: data generation, preprocessing, descriptive analysis, hypothesis testing, interpretation, presentation

**Suggested visual/chart/table:**  
Table: member, ID, contribution.

**Speaker notes:**  
Keep short. Do not spend time on technical details here.

**Supporting output/result:**  
Group information still needed from team.

---

## Slide 3

**Template section:** Problem Statement  
**Slide title:** Why One Result Was Not Enough  
**Importance:** Essential

**Main message:**  
One dataset or one model result cannot justify a statement about many prediction tasks.

**Content bullets:**

- Model performance changes by dataset.
- Model performance changes by metric.
- Model performance changes by train-test split.
- Single model-pair results may be misleading.
- Therefore, we used many paired comparisons.

**Suggested visual/chart/table:**  
Simple comparison: `one result = weak evidence` vs `many paired comparisons = stronger evidence`.

**Speaker notes:**  
This slide justifies the project design. It explains why we needed a generated comparison dataset.

**Supporting output/result:**  
`outputs/final_project_analysis/final_interpretation_summary.md`, Sections 2 and 3

---

## Slide 4

**Template section:** Objectives  
**Slide title:** Project Objectives  
**Importance:** Essential

**Main message:**  
The objective was to test the statement using descriptive and inferential analysis.

**Content bullets:**

- Generate a paired comparison dataset.
- Compare ensemble models against single models.
- Summarize wins, losses, and ties.
- Visualize patterns by task, metric, dataset, and model pair.
- Test whether ensemble win proportion is greater than 50%.
- Make a final decision without overclaiming.

**Suggested visual/chart/table:**  
Flow: `data -> model comparisons -> descriptive analysis -> hypothesis test -> decision`.

**Speaker notes:**  
Say the final decision depends on both model results and statistical interpretation.

**Supporting output/result:**  
All final analysis folders, especially `04_hypothesis_testing/`

---

## Slide 5

**Template section:** Data Collection  
**Slide title:** Evidence Dataset  
**Importance:** Essential

**Main message:**  
The final evidence was a 13,950-row paired comparison dataset.

**Content bullets:**

- Main CSV: `analysis_ready_pairwise.csv`
- 13,950 paired comparison rows
- 19 datasets
- 2 task types: classification and regression
- 10 metrics
- 6 model pairs
- No time-series rows

**Suggested visual/chart/table:**  
Dataset profile table.

**Speaker notes:**  
This slide answers where the evidence came from. Do not read the full file path aloud.

**Supporting output/result:**  
`outputs/final_project_analysis/02_descriptive_summaries/overall_descriptive_summary.csv`  
`outputs/final_project_analysis/01_data_understanding/basic_structure.csv`

---

## Slide 6

**Template section:** Data Collection  
**Slide title:** What One Row Represents  
**Importance:** Essential

**Main message:**  
One row is one split-level paired comparison between a single model and an ensemble model.

**Content bullets:**

- Same task type
- Same dataset
- Same fold/repeat context
- Same metric
- One single model vs one ensemble model
- `difference_value > 0`: ensemble wins
- `difference_value < 0`: single model wins
- `difference_value = 0`: tie

**Suggested visual/chart/table:**  
Diagram: `dataset + split + metric + model pair -> single score vs ensemble score -> difference_value -> win/loss/tie`.

**Speaker notes:**  
This is a viva-critical slide. "Paired" means the comparison happens under the same context.

**Supporting output/result:**  
`outputs/final_project_analysis/final_interpretation_summary.md`, Section 4

---

## Slide 7

**Template section:** Data Preprocessing  
**Slide title:** Folds, Repeats, And Data Readiness  
**Importance:** Essential

**Main message:**  
Folds and repeats made the evidence stronger than one split, and readiness checks confirmed the dataset was usable.

**Content bullets:**

- One split can be lucky or unlucky.
- Folds/repeats check performance across multiple split-level situations.
- All rows were valid pairs.
- Required analysis columns existed.
- Numeric metric columns were usable.
- Time-series rows were absent.
- Ties were handled directly using `difference_value`.

**Suggested visual/chart/table:**  
Small readiness table plus simple fold/repeat icon.

**Speaker notes:**  
Mention Step 1 confirmed the data was analysis-ready. If asked about one sign-check mismatch, explain final logic used direct positive/negative/zero difference rules.

**Supporting output/result:**  
`outputs/final_project_analysis/01_data_understanding/readiness_checks.csv`  
`outputs/final_project_analysis/01_data_understanding/counts_fold.csv`  
`outputs/final_project_analysis/01_data_understanding/counts_repeat_id.csv`

---

## Slide 8

**Template section:** Predictive Model  
**Slide title:** Predictive Modelling Role  
**Importance:** Essential

**Main message:**  
Predictive models generated the evidence; statistical analysis interpreted the overall pattern.

**Content bullets:**

- Single and ensemble models were trained/evaluated across datasets.
- Metrics measured predictive performance.
- Metric values were converted into paired comparison rows.
- The final decision was based on repeated paired evidence, not one accuracy score.

**Suggested visual/chart/table:**  
Pipeline: `datasets -> single/ensemble models -> metric scores -> paired comparison CSV -> analysis`.

**Speaker notes:**  
This satisfies the template's predictive model section. The focus is comparison and interpretation, not only best accuracy.

**Supporting output/result:**  
Main evidence CSV  
`outputs/final_project_analysis/final_interpretation_summary.md`, Sections 3 and 4

---

## Slide 9

**Template section:** Descriptive Analysis  
**Slide title:** Overall Descriptive Findings  
**Importance:** Essential

**Main message:**  
Before hypothesis testing, descriptive results showed a strong ensemble-win pattern.

**Content bullets:**

- Total paired rows: 13,950
- Ensemble wins: 11,910
- Single-model wins: 1,779
- Ties: 261
- All-row ensemble win rate: 85.38%
- Non-tie ensemble win rate: 87.00%

**Suggested visual/chart/table:**  
Win/loss/tie count table or stacked bar.

**Speaker notes:**  
Explain both win rates. All-row includes ties in the denominator. Non-tie excludes ties and matches the testing logic.

**Supporting output/result:**  
`outputs/final_project_analysis/02_descriptive_summaries/overall_descriptive_summary.csv`

---

## Slide 10

**Template section:** Descriptive Analysis  
**Slide title:** Descriptive Patterns By Task And Metric  
**Importance:** Essential

**Main message:**  
The ensemble advantage appeared in both task types and across metrics, but strength varied.

**Content bullets:**

- Classification non-tie win rate: 87.54%
- Regression non-tie win rate: 86.19%
- Metric win rates were generally above 50%.
- MAPE was flagged as cautionary.
- Variation by metric shows why interpretation matters.

**Suggested visual/chart/table:**  
Use:

- `outputs/final_project_analysis/03_descriptive_plots/01_win_rate_by_task_type.png`
- `outputs/final_project_analysis/03_descriptive_plots/03_win_rate_by_metric.png`

**Speaker notes:**  
Do not overclaim that every metric behaves the same. Say the broad pattern supports the statement, but variation exists.

**Supporting output/result:**  
`outputs/final_project_analysis/02_descriptive_summaries/summary_by_task_type.csv`  
`outputs/final_project_analysis/02_descriptive_summaries/summary_by_metric.csv`

---

## Slide 11

**Template section:** Inferential Analysis  
**Slide title:** Hypothesis Test Setup  
**Importance:** Essential

**Main message:**  
The main statistical test was a one-population proportion test on ensemble wins.

**Content bullets:**

- Non-tied row outcome:
  - success = ensemble win
  - failure = single-model win
- H0: ensemble win proportion = 0.50
- H1: ensemble win proportion > 0.50
- Alpha = 0.05
- Exact one-sided binomial test used
- MAPE excluded from headline test
- Ties counted separately and excluded from denominator

**Suggested visual/chart/table:**  
Hypothesis setup box with H0/H1 and denominator definition.

**Speaker notes:**  
Connect to lecture concepts: statistical inference, hypothesis testing, and population proportion.

**Supporting output/result:**  
`outputs/final_project_analysis/04_hypothesis_testing/headline_win_rate_tests.csv`  
`archive/notes/Lessons learned from lectures for project .md`

---

## Slide 12

**Template section:** Inferential Analysis  
**Slide title:** Headline Hypothesis Result  
**Importance:** Essential

**Main message:**  
The test gave strong statistical evidence that ensembles win more often than 50%.

**Content bullets:**

- Tested non-tie rows: 12,339
- Ensemble wins: 10,797
- Single-model wins: 1,542
- Headline win rate: 87.50%
- 95% CI: 86.91% to 88.08%
- p-value: < 0.001
- Decision: reject H0

**Suggested visual/chart/table:**  
Result card: win rate, confidence interval, p-value, decision. Optional small bar: 87.50% vs 50%.

**Speaker notes:**  
This is the strongest evidence slide. Explain that p-value < 0.001 means the observed result is extremely unlikely if true win rate were only 50%.

**Supporting output/result:**  
`outputs/final_project_analysis/04_hypothesis_testing/headline_win_rate_tests.csv`

---

## Slide 13

**Template section:** Results  
**Slide title:** What The Results Mean  
**Importance:** Essential

**Main message:**  
Descriptive and inferential results both support an ensemble advantage within the project scope.

**Content bullets:**

- Descriptive non-tie win rate: 87.00%
- Headline non-MAPE test win rate: 87.50%
- 95% CI: 86.91% to 88.08%
- p-value: < 0.001
- Both classification and regression showed high win rates.
- Evidence supports the statement for tested classification and regression comparisons.

**Suggested visual/chart/table:**  
Three-part summary: descriptive evidence, statistical evidence, scope statement.

**Speaker notes:**  
Translate numbers into meaning. Say "supports the statement" rather than "proves ensembles are always better."

**Supporting output/result:**  
`outputs/final_project_analysis/final_interpretation_summary.md`, Sections 9 and 11

---

## Slide 14

**Template section:** Final Decision  
**Slide title:** Final Decision On The Statement  
**Importance:** Essential

**Main message:**  
The statement is supported by the tested evidence.

**Content bullets:**

- Statistical decision: reject H0.
- Project decision: statement is supported within scope.
- Ensembles won most non-tied paired comparisons.
- This is not a universal proof.
- Scope: classification and regression benchmark comparisons only.

**Suggested visual/chart/table:**  
Two boxes:

- Statistical decision: reject H0
- Project decision: statement supported within scope

**Speaker notes:**  
Use careful wording. In statistics, reject H0. In project interpretation, statement is supported.

**Supporting output/result:**  
`outputs/final_project_analysis/04_hypothesis_testing/headline_win_rate_tests.csv`  
`outputs/final_project_analysis/final_interpretation_summary.md`, Section 11

---

## Slide 15

**Template section:** Conclusion  
**Slide title:** Limitations And Cautions  
**Importance:** Essential

**Main message:**  
The evidence is strong, but the conclusion must remain honest.

**Content bullets:**

- Does not prove ensembles are always better.
- Results depend on selected datasets, models, metrics, folds, and repeats.
- MAPE is cautionary and excluded from the headline test.
- Ties are counted separately.
- Rows share datasets/folds/model pairs, so independence is not perfect.
- Time-series tasks are outside final scope.

**Suggested visual/chart/table:**  
Table: caution -> how handled.

**Speaker notes:**  
This slide improves credibility. It also prepares team members for viva questions.

**Supporting output/result:**  
`outputs/final_project_analysis/final_interpretation_summary.md`, Section 12  
`outputs/final_project_analysis/04_hypothesis_testing/analysis_method_decisions.csv`

---

## Slide 16

**Template section:** Conclusion  
**Slide title:** Final Takeaway  
**Importance:** Essential

**Main message:**  
Ensembles performed better in most tested paired comparisons.

**Content bullets:**

- We used many paired comparisons, not one isolated result.
- Descriptive analysis showed high ensemble win rates.
- Hypothesis testing showed statistically significant evidence.
- Final conclusion: statement is supported for tested classification and regression tasks.

**Suggested visual/chart/table:**  
Final wording:

> Excluding MAPE and ties from the test denominator, ensembles won 87.50% of non-tied comparisons (95% CI: 86.91% to 88.08%, p < 0.001). This supports the project statement for the tested classification and regression tasks.

**Speaker notes:**  
End with one clear final result. Do not introduce new analysis.

**Supporting output/result:**  
`outputs/final_project_analysis/final_interpretation_summary.md`, Section 13

---

## Optional Backup Slide A

**Template section:** Inferential Analysis  
**Slide title:** Why ANOVA And Variance Tests Were Not Used As Main Evidence  
**Importance:** Optional

**Main message:**  
The main claim is about win frequency, so a population proportion test is the cleanest match.

**Content bullets:**

- ANOVA compares group means.
- Variance tests compare spread.
- Main statement asks whether ensembles perform better more often.
- Win/loss proportion directly matches the claim.
- Difference-value tests were kept secondary and metric-specific.

**Suggested visual/chart/table:**  
Method decision table excerpt.

**Speaker notes:**  
Use only if lecturer asks why other lecture methods were not used.

**Supporting output/result:**  
`outputs/final_project_analysis/04_hypothesis_testing/analysis_method_decisions.csv`

---

## Optional Backup Slide B

**Template section:** Descriptive Analysis / Results  
**Slide title:** Extra Variation By Dataset Or Model Pair  
**Importance:** Optional

**Main message:**  
The ensemble advantage was broad, but not identical across all datasets and model pairs.

**Content bullets:**

- Some datasets showed stronger ensemble win rates.
- Some datasets showed weaker ensemble win rates.
- Model-pair differences are expected.
- This supports honest interpretation and avoids overclaiming.

**Suggested visual/chart/table:**  
Use one:

- `outputs/final_project_analysis/03_descriptive_plots/02_win_rate_by_dataset.png`
- `outputs/final_project_analysis/03_descriptive_plots/04_win_rate_by_model_pair.png`

**Speaker notes:**  
Use if time allows or as appendix for viva questions.

**Supporting output/result:**  
`outputs/final_project_analysis/02_descriptive_summaries/summary_by_dataset.csv`  
`outputs/final_project_analysis/02_descriptive_summaries/summary_by_model_pair.csv`

---

## Build Notes For Real Deck

Missing before slide building:

- Final group member names and student IDs
- Exact contribution split
- Presentation time limit
- Whether appendix slides are allowed
- Whether original IT3011 PowerPoint template styling must be followed exactly

Ready status:

- Analysis story is ready.
- Core numbers are available.
- Best plots are already generated.
- Ready to start the real browser-slide deck after group details and timing are confirmed.
