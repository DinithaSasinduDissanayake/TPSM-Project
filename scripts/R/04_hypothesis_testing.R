#!/usr/bin/env Rscript

# Phase 2A Step 4: Hypothesis testing.
# This script tests whether ensemble models win more often than single models.
# It does not modify the original input CSV.

args <- commandArgs(trailingOnly = TRUE)

DATA_PATH <- if (length(args) >= 1) {
  args[1]
} else {
  "outputs/archive/legacy/py_full_no_timeseries_probe/20260421T231947/analysis_ready_pairwise.csv"
}

OUTPUT_DIR <- if (length(args) >= 2) {
  args[2]
} else {
  "outputs/final_project_analysis/04_hypothesis_testing"
}

ALPHA <- 0.05
CONFIDENCE_LEVEL <- 0.95
MAPE_METRIC <- "mape"

if (!file.exists(DATA_PATH)) {
  stop(paste("Input CSV not found:", DATA_PATH))
}

if (!dir.exists(OUTPUT_DIR)) {
  dir.create(OUTPUT_DIR, recursive = TRUE)
}

normalize_bool <- function(x) {
  if (is.logical(x)) {
    return(x)
  }
  y <- tolower(trimws(as.character(x)))
  out <- rep(NA, length(y))
  out[y %in% c("true", "t", "1")] <- TRUE
  out[y %in% c("false", "f", "0")] <- FALSE
  out
}

format_p <- function(p_value) {
  if (is.na(p_value)) {
    return("NA")
  }
  if (p_value < 0.001) {
    return("< 0.001")
  }
  format(round(p_value, 4), nsmall = 4)
}

make_decision <- function(p_value) {
  if (is.na(p_value)) {
    return("not tested")
  }
  if (p_value < ALPHA) {
    return("reject H0")
  }
  "fail to reject H0"
}

make_interpretation_label <- function(p_value) {
  if (is.na(p_value)) {
    return("not_tested")
  }
  if (p_value < ALPHA) {
    return("statistically_significant_ensemble_advantage")
  }
  "not_statistically_significant"
}

make_mape_status <- function(test_name, include_mape, group_label) {
  if (group_label == MAPE_METRIC) {
    return("metric_is_mape_caution")
  }
  if (test_name == "headline_excluding_mape") {
    return("mape_excluded_from_headline")
  }
  if (test_name == "sensitivity_including_mape") {
    return("mape_included_for_sensitivity")
  }
  if (include_mape) {
    return("mape_included")
  }
  "mape_excluded"
}

required_columns <- c(
  "task_type",
  "dataset_id",
  "metric_name",
  "difference_value",
  "valid_pair"
)

df <- read.csv(DATA_PATH, stringsAsFactors = FALSE)

if ("valid_pair" %in% names(df)) {
  df$valid_pair <- normalize_bool(df$valid_pair)
}

missing_columns <- setdiff(required_columns, names(df))
if (length(missing_columns) > 0) {
  stop(paste("Required columns missing:", paste(missing_columns, collapse = ", ")))
}

df <- df[df$valid_pair == TRUE & !is.na(df$valid_pair), ]
df <- df[is.finite(df$difference_value), ]

df$win_status <- ifelse(
  df$difference_value > 0,
  "ensemble_win",
  ifelse(df$difference_value < 0, "single_win", "tie")
)

cat("=== TPSM Phase 2A Step 4: Hypothesis Testing ===\n")
cat("Input:", DATA_PATH, "\n")
cat("Output:", OUTPUT_DIR, "\n")
cat("Alpha:", ALPHA, "\n\n")

run_win_rate_test <- function(data, test_name, include_mape, group_label = "overall") {
  wins <- sum(data$win_status == "ensemble_win", na.rm = TRUE)
  losses <- sum(data$win_status == "single_win", na.rm = TRUE)
  ties <- sum(data$win_status == "tie", na.rm = TRUE)
  trials <- wins + losses

  if (trials > 0) {
    one_sided_test <- stats::binom.test(
      x = wins,
      n = trials,
      p = 0.5,
      alternative = "greater",
      conf.level = CONFIDENCE_LEVEL
    )
    estimation_ci <- stats::binom.test(
      x = wins,
      n = trials,
      p = 0.5,
      alternative = "two.sided",
      conf.level = CONFIDENCE_LEVEL
    )
    p_value <- one_sided_test$p.value
    one_sided_conf_low <- unname(one_sided_test$conf.int[1])
    one_sided_conf_high <- unname(one_sided_test$conf.int[2])
    estimate_conf_low <- unname(estimation_ci$conf.int[1])
    estimate_conf_high <- unname(estimation_ci$conf.int[2])
  } else {
    p_value <- NA_real_
    one_sided_conf_low <- NA_real_
    one_sided_conf_high <- NA_real_
    estimate_conf_low <- NA_real_
    estimate_conf_high <- NA_real_
  }

  data.frame(
    test_name = test_name,
    group_label = group_label,
    include_mape = include_mape,
    mape_status = make_mape_status(test_name, include_mape, group_label),
    row_count = nrow(data),
    ensemble_wins = wins,
    single_wins = losses,
    ties = ties,
    tested_non_tie_rows = trials,
    denominator_definition = "ensemble_wins + single_wins; ties excluded",
    tie_handling = "ties counted separately and excluded from test denominator",
    observed_win_rate_excluding_ties = ifelse(trials > 0, wins / trials, NA_real_),
    null_win_rate = 0.5,
    alternative = "ensemble win rate > 0.5",
    test_used = "Exact one-sided binomial test",
    test_statistic = wins,
    success_count = wins,
    trial_count = trials,
    p_value = p_value,
    p_value_display = format_p(p_value),
    confidence_level = CONFIDENCE_LEVEL,
    one_sided_conf_int_low = one_sided_conf_low,
    one_sided_conf_int_high = one_sided_conf_high,
    estimate_conf_int_95_low = estimate_conf_low,
    estimate_conf_int_95_high = estimate_conf_high,
    conf_int_low = one_sided_conf_low,
    conf_int_high = one_sided_conf_high,
    alpha = ALPHA,
    decision = make_decision(p_value),
    interpretation_label = make_interpretation_label(p_value),
    stringsAsFactors = FALSE
  )
}

run_difference_test <- function(data, test_name, group_label) {
  x <- data$difference_value
  x <- x[is.finite(x)]

  if (length(x) >= 2 && stats::sd(x) > 0) {
    test <- stats::t.test(x, mu = 0, alternative = "greater")
    p_value <- test$p.value
    mean_diff <- unname(test$estimate)
    conf_low <- unname(test$conf.int[1])
    conf_high <- unname(test$conf.int[2])
  } else {
    p_value <- NA_real_
    mean_diff <- ifelse(length(x) > 0, mean(x), NA_real_)
    conf_low <- NA_real_
    conf_high <- NA_real_
  }

  data.frame(
    test_name = test_name,
    group_label = group_label,
    row_count = length(x),
    mean_difference = mean_diff,
    median_difference = ifelse(length(x) > 0, stats::median(x), NA_real_),
    test_used = "One-sample one-sided t-test on difference_value",
    null_mean_difference = 0,
    alternative = "mean difference_value > 0",
    p_value = p_value,
    p_value_display = format_p(p_value),
    confidence_level = CONFIDENCE_LEVEL,
    conf_int_low = conf_low,
    conf_int_high = conf_high,
    alpha = ALPHA,
    decision = make_decision(p_value),
    interpretation_label = make_interpretation_label(p_value),
    caution = "Secondary only: difference_value units are not comparable across different metrics.",
    stringsAsFactors = FALSE
  )
}

main_df <- df[df$metric_name != MAPE_METRIC, ]
sensitivity_df <- df

main_win_test <- run_win_rate_test(
  main_df,
  "headline_excluding_mape",
  include_mape = FALSE,
  group_label = "all_non_mape_metrics"
)

sensitivity_win_test <- run_win_rate_test(
  sensitivity_df,
  "sensitivity_including_mape",
  include_mape = TRUE,
  group_label = "all_metrics"
)

task_level_tests <- do.call(
  rbind,
  lapply(split(main_df, main_df$task_type, drop = TRUE), function(group_data) {
    run_win_rate_test(
      group_data,
      "task_level_excluding_mape",
      include_mape = FALSE,
      group_label = unique(group_data$task_type)[1]
    )
  })
)

metric_level_tests <- do.call(
  rbind,
  lapply(split(df, df$metric_name, drop = TRUE), function(group_data) {
    run_win_rate_test(
      group_data,
      "metric_level",
      include_mape = unique(group_data$metric_name)[1] == MAPE_METRIC,
      group_label = unique(group_data$metric_name)[1]
    )
  })
)

difference_tests_by_metric <- do.call(
  rbind,
  lapply(split(df, df$metric_name, drop = TRUE), function(group_data) {
    run_difference_test(
      group_data,
      "difference_test_by_metric",
      group_label = unique(group_data$metric_name)[1]
    )
  })
)

headline_summary <- rbind(main_win_test, sensitivity_win_test)

all_win_tests <- rbind(
  headline_summary,
  task_level_tests,
  metric_level_tests
)

write.csv(
  headline_summary,
  file.path(OUTPUT_DIR, "headline_win_rate_tests.csv"),
  row.names = FALSE
)

write.csv(
  task_level_tests,
  file.path(OUTPUT_DIR, "task_level_win_rate_tests_excluding_mape.csv"),
  row.names = FALSE
)

write.csv(
  metric_level_tests,
  file.path(OUTPUT_DIR, "metric_level_win_rate_tests.csv"),
  row.names = FALSE
)

write.csv(
  all_win_tests,
  file.path(OUTPUT_DIR, "all_win_rate_tests.csv"),
  row.names = FALSE
)

write.csv(
  difference_tests_by_metric,
  file.path(OUTPUT_DIR, "difference_tests_by_metric.csv"),
  row.names = FALSE
)

method_decisions <- data.frame(
  analysis_area = c(
    "Headline claim",
    "Confidence interval reporting",
    "Tie handling",
    "MAPE handling",
    "Difference-value tests",
    "Mixed-metric mean difference",
    "ANOVA",
    "Population variance tests"
  ),
  decision = c(
    "Use exact one-sided binomial proportion test.",
    "Report two-sided 95% exact confidence interval for estimated win proportion.",
    "Count ties separately and exclude them from win-rate test denominator.",
    "Exclude MAPE from headline; include only as sensitivity and metric-level caution.",
    "Keep one-sample one-sided t-tests by metric only as secondary evidence.",
    "Do not use as headline.",
    "Do not add.",
    "Do not add."
  ),
  reason = c(
    "Main outcome is whether ensemble wins more often than single model among non-tied paired comparisons.",
    "One-sided test answers directional hypothesis; two-sided interval is easier to report as estimate precision.",
    "Ties are neither ensemble wins nor single-model wins, so they should not enter Bernoulli win/loss denominator.",
    "MAPE can be unstable with small target values, so it should not drive headline conclusion.",
    "Raw difference_value units are comparable within metric, but not across metrics.",
    "Metrics have different units and scales, so a combined mean difference would be misleading.",
    "ANOVA compares group means and would add complexity without directly testing the project claim.",
    "Variance comparisons do not answer whether ensembles perform better."
  ),
  risk_level = c(
    "low",
    "low",
    "low",
    "low",
    "medium",
    "high_if_added",
    "high_if_added",
    "high_if_added"
  ),
  stringsAsFactors = FALSE
)

write.csv(
  method_decisions,
  file.path(OUTPUT_DIR, "analysis_method_decisions.csv"),
  row.names = FALSE
)

clean_summary <- data.frame(
  analysis_item = c(
    "Main headline test",
    "Sensitivity test",
    "Task-level tests",
    "Metric-level tests",
    "Difference-value tests",
    "Analysis method decisions"
  ),
  output_file = c(
    "headline_win_rate_tests.csv",
    "headline_win_rate_tests.csv",
    "task_level_win_rate_tests_excluding_mape.csv",
    "metric_level_win_rate_tests.csv",
    "difference_tests_by_metric.csv",
    "analysis_method_decisions.csv"
  ),
  description = c(
    "Exact binomial test of ensemble wins vs single-model wins, excluding MAPE.",
    "Same exact binomial test with MAPE included.",
    "Exact binomial tests by task type, excluding MAPE.",
    "Exact binomial tests by metric. MAPE is included here but should be interpreted with caution.",
    "Secondary one-sample t-tests on difference_value within each metric.",
    "Course-method decision table for included and excluded statistical methods."
  ),
  stringsAsFactors = FALSE
)

write.csv(
  clean_summary,
  file.path(OUTPUT_DIR, "hypothesis_test_summary.csv"),
  row.names = FALSE
)

main_rate <- main_win_test$observed_win_rate_excluding_ties[1]
sensitivity_rate <- sensitivity_win_test$observed_win_rate_excluding_ties[1]

notes <- c(
  "# Phase 2A Step 4: Hypothesis Testing",
  "",
  paste("Input CSV:", DATA_PATH),
  paste("Output folder:", OUTPUT_DIR),
  paste("Alpha level:", ALPHA),
  "",
  "## Main Hypothesis",
  "",
  "The main analysis uses win/loss outcomes instead of raw metric differences.",
  "",
  "- H0: ensemble win rate = 50%",
  "- H1: ensemble win rate > 50%",
  "",
  "A win means `difference_value > 0`. A single-model win means `difference_value < 0`. A tie means `difference_value == 0`.",
  "",
  "Ties are counted and reported, but they are not counted as ensemble wins and they are not included in the binomial-test denominator.",
  "",
  "## Main Test Result, Excluding MAPE",
  "",
  paste("- Ensemble wins:", main_win_test$ensemble_wins[1]),
  paste("- Single-model wins:", main_win_test$single_wins[1]),
  paste("- Ties:", main_win_test$ties[1]),
  paste("- Tested non-tie rows:", main_win_test$tested_non_tie_rows[1]),
  paste("- Observed ensemble win rate among non-ties:", paste0(round(main_rate * 100, 2), "%")),
  paste("- Test used:", main_win_test$test_used[1]),
  paste0(
    "- 95% confidence interval for estimated win proportion: ",
    round(main_win_test$estimate_conf_int_95_low[1] * 100, 2), "% to ",
    round(main_win_test$estimate_conf_int_95_high[1] * 100, 2), "%"
  ),
  paste("- p-value:", format_p(main_win_test$p_value[1])),
  paste("- Decision at alpha = 0.05:", main_win_test$decision[1]),
  "",
  "Interpretation: if the true ensemble win rate were only 50%, this p-value is the probability of seeing a win count this high or higher just by random chance under the null model.",
  "",
  "## Sensitivity Test, Including MAPE",
  "",
  paste("- Ensemble wins:", sensitivity_win_test$ensemble_wins[1]),
  paste("- Single-model wins:", sensitivity_win_test$single_wins[1]),
  paste("- Ties:", sensitivity_win_test$ties[1]),
  paste("- Tested non-tie rows:", sensitivity_win_test$tested_non_tie_rows[1]),
  paste("- Observed ensemble win rate among non-ties:", paste0(round(sensitivity_rate * 100, 2), "%")),
  paste0(
    "- 95% confidence interval for estimated win proportion: ",
    round(sensitivity_win_test$estimate_conf_int_95_low[1] * 100, 2), "% to ",
    round(sensitivity_win_test$estimate_conf_int_95_high[1] * 100, 2), "%"
  ),
  paste("- p-value:", format_p(sensitivity_win_test$p_value[1])),
  paste("- Decision at alpha = 0.05:", sensitivity_win_test$decision[1]),
  "",
  "This checks whether the headline conclusion changes when MAPE is included. MAPE is kept out of the headline result because it can be unstable when target values are very small.",
  "",
  "## Extra Tests",
  "",
  "- `task_level_win_rate_tests_excluding_mape.csv` repeats the win-rate test separately for classification and regression.",
  "- `metric_level_win_rate_tests.csv` repeats the win-rate test separately for each metric.",
  "- `difference_tests_by_metric.csv` gives secondary one-sided t-tests on `difference_value` within each metric.",
  "",
  "The difference-value tests should not be the main evidence because raw `difference_value` has different units for different metrics. For example, accuracy and F1 are small decimal-scale metrics, while MAE and RMSE are in original target units.",
  "",
  "## What We Can Conclude",
  "",
  "For this recovered paired-comparison dataset, ensemble models win significantly more often than 50% of the non-tied comparisons in the headline analysis.",
  "",
  "## What We Cannot Overclaim",
  "",
  "- This does not prove ensembles are always better.",
  "- The rows are split-level paired comparisons, so many rows come from the same datasets, model pairs, and metrics. The binomial test is a simple course-appropriate test, but it treats tested rows as Bernoulli trials.",
  "- A statistically significant win rate does not automatically mean every individual dataset, model pair, or metric favors ensembles.",
  "- MAPE results should be interpreted cautiously because MAPE can behave poorly when actual target values are near zero.",
  "",
  "## Output Files",
  "",
  "- `hypothesis_test_summary.csv`: quick map of Step 4 output files.",
  "- `headline_win_rate_tests.csv`: main and sensitivity win-rate tests.",
  "- `task_level_win_rate_tests_excluding_mape.csv`: optional tests by task type.",
  "- `metric_level_win_rate_tests.csv`: optional tests by metric.",
  "- `all_win_rate_tests.csv`: combined win-rate test table.",
  "- `difference_tests_by_metric.csv`: secondary difference-value tests by metric.",
  "- `analysis_method_decisions.csv`: short decision table explaining included and excluded statistical methods.",
  "- `hypothesis_testing_notes.md`: this explanation."
)

writeLines(notes, file.path(OUTPUT_DIR, "hypothesis_testing_notes.md"))

cat("Wrote Step 4 outputs:\n")
cat("- hypothesis_test_summary.csv\n")
cat("- headline_win_rate_tests.csv\n")
cat("- task_level_win_rate_tests_excluding_mape.csv\n")
cat("- metric_level_win_rate_tests.csv\n")
cat("- all_win_rate_tests.csv\n")
cat("- difference_tests_by_metric.csv\n")
cat("- analysis_method_decisions.csv\n")
cat("- hypothesis_testing_notes.md\n\n")

cat("Main test excluding MAPE: win rate = ", round(main_rate, 4),
    ", p-value = ", format_p(main_win_test$p_value[1]), "\n", sep = "")
cat("Sensitivity including MAPE: win rate = ", round(sensitivity_rate, 4),
    ", p-value = ", format_p(sensitivity_win_test$p_value[1]), "\n", sep = "")
