# TPSM Master Plan

## Purpose

This file is the single working source of truth for the IT3011 / TPSM assignment.
It combines lecture guidance, assignment briefing, and the current project direction.

## What The Assignment Actually Wants

- Select one statement to test or justify.
- Use data analysis to support or reject that statement.
- Cover descriptive, inferential, and predictive analytics.
- Focus on interpretation, not only model accuracy.
- Use a dataset that matches the statement and is realistically obtainable.
- Secondary data is preferred, but primary data is allowed if sampling is proper.
- If primary data is used, target at least 300 records.
- If multiple datasets help the argument, they are allowed.
- Tools are flexible: R is recommended, but Python, SPSS, Power BI, and Tableau are allowed.

## Key Lecture Rules

- H0 is the stable / no-problem case.
- H1 is the problem / question case.
- Hypothesis tests use a sample, not the full population.
- A test result is never 100 percent proof of truth.
- Type I error is the dangerous one: reject a correct H0.
- Alpha is the risk level you accept when testing.
- For exam-style hypothesis framing, put the question in H1 and the stable claim in H0.

## Assignment Workflow

### 1. Statement And Scope

- Pick one clear research statement.
- Define the response variable.
- Define possible predictors.
- Keep the scope narrow enough to analyze well.

### 2. Data Selection

- Prefer publicly available secondary data.
- Use Kaggle, UCI, or other reliable open datasets.
- Make sure the dataset matches the statement.
- Check whether the variables are enough to justify the claim.
- Avoid fake or artificially filled primary data.

### 3. Descriptive Analytics

- Describe every important variable.
- State data types.
- Check missing values.
- Check distribution shape.
- Compute summary statistics.
- Use plots to show spread, skewness, correlation, and outliers.

### 4. Inferential Analytics

- State H0 and H1 clearly.
- Use appropriate hypothesis tests.
- Report p-values against alpha.
- Explain what the test means in plain language.
- Be honest: sample evidence is not absolute population truth.

### 5. Predictive Analytics

- Build models that help test the statement.
- Compare simpler and stronger models.
- Explain model choice.
- Report the result in terms of prediction quality and interpretation.

### 6. Viva / Mid-Evaluation

- No report or presentation is required for the viva phase.
- Be ready to explain the topic, data source, and methods.
- Every team member must understand the work.
- Questions may go to any one member randomly.
- The group mark depends on viva performance.

## Recommended Dataset Direction

- Wine Quality: good for regression and model comparison.
- Bike Sharing: good for regression with time structure.
- Breast Cancer Wisconsin: good for classification and Naive Bayes style comparison.
- If the repo uses different datasets, keep this plan as the assignment narrative only, not as the pipeline source.

## What To Do Next

- Finalize one clean research statement.
- Finalize dataset choice.
- Decide the exact models to compare.
- Write the descriptive, inferential, and predictive sections separately.
- Keep one master file and do not spread the plan across many markdown files.

## Current Repo Note

- The existing codebase has its own benchmark pipeline and dataset config.
- That pipeline should stay separate from this assignment plan unless you intentionally align them.
- This file is only for the assignment workflow and planning layer.
