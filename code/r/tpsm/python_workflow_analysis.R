#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(ggplot2)
})

args <- commandArgs(trailingOnly = TRUE)

default_input_dir <- file.path("outputs", "py_smoke_stage2", "20260421T202008")
input_dir <- if (length(args) >= 1) args[[1]] else default_input_dir
output_dir <- if (length(args) >= 2) args[[2]] else file.path(input_dir, "r_analysis")

pairwise_path <- file.path(input_dir, "analysis_ready_pairwise.csv")
cleaning_path <- file.path(input_dir, "dataset_cleaning_summary.csv")

if (!file.exists(pairwise_path)) {
  stop(sprintf("Missing file: %s", pairwise_path))
}

if (!file.exists(cleaning_path)) {
  stop(sprintf("Missing file: %s", cleaning_path))
}

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

pairwise_df <- read_csv(pairwise_path, show_col_types = FALSE) %>%
  mutate(
    task_type = as.factor(task_type),
    metric_name = as.factor(metric_name),
    model_pair = as.factor(model_pair),
    ensemble_better = as.logical(ensemble_better),
    higher_better = as.logical(higher_better),
    valid_pair = as.logical(valid_pair)
  ) %>%
  filter(valid_pair)

cleaning_df <- read_csv(cleaning_path, show_col_types = FALSE)

write_csv(cleaning_df, file.path(output_dir, "cleaning_summary_copy.csv"))

overall_summary <- tibble(
  n_rows = nrow(pairwise_df),
  n_task_types = n_distinct(pairwise_df$task_type),
  n_datasets = n_distinct(pairwise_df$dataset_id),
  n_model_pairs = n_distinct(pairwise_df$model_pair),
  n_metrics = n_distinct(pairwise_df$metric_name),
  mean_difference = mean(pairwise_df$difference_value, na.rm = TRUE),
  median_difference = median(pairwise_df$difference_value, na.rm = TRUE),
  sd_difference = sd(pairwise_df$difference_value, na.rm = TRUE),
  min_difference = min(pairwise_df$difference_value, na.rm = TRUE),
  max_difference = max(pairwise_df$difference_value, na.rm = TRUE),
  ensemble_win_rate = mean(pairwise_df$ensemble_better, na.rm = TRUE)
)

grouped_summary <- pairwise_df %>%
  group_by(task_type, metric_name, model_pair) %>%
  summarise(
    n = n(),
    mean_difference = mean(difference_value, na.rm = TRUE),
    median_difference = median(difference_value, na.rm = TRUE),
    sd_difference = sd(difference_value, na.rm = TRUE),
    ensemble_win_rate = mean(ensemble_better, na.rm = TRUE),
    .groups = "drop"
  )

cleaning_brief <- cleaning_df %>%
  transmute(
    task_type,
    dataset_id,
    raw_rows,
    prepared_rows,
    rows_removed_total,
    missing_cells_before,
    missing_cells_after_prepare,
    duplicate_rows_before,
    duplicate_rows_after_prepare,
    numeric_outlier_cells_before,
    numeric_outlier_cells_after_prepare
  )

write_csv(overall_summary, file.path(output_dir, "overall_summary.csv"))
write_csv(grouped_summary, file.path(output_dir, "grouped_summary.csv"))
write_csv(cleaning_brief, file.path(output_dir, "cleaning_brief.csv"))

safe_shapiro <- function(x) {
  vals <- x[is.finite(x)]
  if (length(vals) < 3 || length(vals) > 5000) {
    return(tibble(
      test = "Shapiro-Wilk normality test",
      statistic = NA_real_,
      p_value = NA_real_,
      estimate = NA_real_,
      conf_low = NA_real_,
      conf_high = NA_real_,
      alternative = NA_character_,
      note = sprintf("skipped_n_%d", length(vals))
    ))
  }
  res <- tryCatch(shapiro.test(vals), error = function(e) e)
  if (inherits(res, "error")) {
    return(tibble(
      test = "error",
      statistic = NA_real_,
      p_value = NA_real_,
      estimate = NA_real_,
      conf_low = NA_real_,
      conf_high = NA_real_,
      alternative = NA_character_,
      note = conditionMessage(res)
    ))
  }
  tibble(
    test = res$method,
    statistic = unname(res$statistic)[1],
    p_value = res$p.value,
    estimate = NA_real_,
    conf_low = NA_real_,
    conf_high = NA_real_,
    alternative = NA_character_,
    note = NA_character_
  )
}

safe_t_test <- function(x) {
  vals <- x[is.finite(x)]
  if (length(vals) < 2) {
    return(tibble(
      test = "One Sample t-test",
      statistic = NA_real_,
      p_value = NA_real_,
      estimate = NA_real_,
      conf_low = NA_real_,
      conf_high = NA_real_,
      alternative = "greater",
      note = sprintf("skipped_n_%d", length(vals))
    ))
  }
  res <- tryCatch(
    t.test(vals, mu = 0, alternative = "greater"),
    error = function(e) e
  )
  if (inherits(res, "error")) {
    return(tibble(
      test = "error",
      statistic = NA_real_,
      p_value = NA_real_,
      estimate = NA_real_,
      conf_low = NA_real_,
      conf_high = NA_real_,
      alternative = "greater",
      note = conditionMessage(res)
    ))
  }
  tibble(
    test = res$method,
    statistic = unname(res$statistic)[1],
    p_value = res$p.value,
    estimate = if (!is.null(res$estimate)) unname(res$estimate)[1] else NA_real_,
    conf_low = if (!is.null(res$conf.int)) res$conf.int[1] else NA_real_,
    conf_high = if (!is.null(res$conf.int)) res$conf.int[2] else NA_real_,
    alternative = res$alternative,
    note = NA_character_
  )
}

overall_normality_result <- safe_shapiro(pairwise_df$difference_value)

prop_successes <- sum(pairwise_df$ensemble_better, na.rm = TRUE)
prop_total <- nrow(pairwise_df)

prop_result <- tryCatch(
  prop.test(x = prop_successes, n = prop_total, p = 0.5, alternative = "greater"),
  error = function(e) e
)

anova_result <- tryCatch(
  summary(aov(difference_value ~ task_type, data = pairwise_df)),
  error = function(e) e
)

format_htest <- function(test_obj) {
  if (inherits(test_obj, "error")) {
    return(tibble(test = "error", detail = conditionMessage(test_obj)))
  }

  tibble(
    test = test_obj$method,
    statistic = unname(test_obj$statistic)[1],
    p_value = test_obj$p.value,
    estimate = if (!is.null(test_obj$estimate)) unname(test_obj$estimate)[1] else NA_real_,
    conf_low = if (!is.null(test_obj$conf.int)) test_obj$conf.int[1] else NA_real_,
    conf_high = if (!is.null(test_obj$conf.int)) test_obj$conf.int[2] else NA_real_,
    alternative = test_obj$alternative
  )
}

grouped_tests <- pairwise_df %>%
  group_by(task_type, metric_name) %>%
  group_modify(~{
    shapiro_row <- safe_shapiro(.x$difference_value) %>%
      mutate(test_kind = "normality")
    t_row <- safe_t_test(.x$difference_value) %>%
      mutate(test_kind = "mean_gt_zero")
    bind_rows(shapiro_row, t_row)
  }) %>%
  ungroup() %>%
  mutate(
    p_value_bh = p.adjust(p_value, method = "BH"),
    p_value_bonferroni = p.adjust(p_value, method = "bonferroni")
  )

write_csv(overall_normality_result, file.path(output_dir, "overall_normality_test.csv"))
write_csv(grouped_tests, file.path(output_dir, "grouped_hypothesis_tests.csv"))
write_csv(format_htest(prop_result), file.path(output_dir, "prop_test_ensemble_win_rate_gt_half.csv"))

anova_lines <- if (inherits(anova_result, "error")) {
  c(sprintf("ANOVA error: %s", conditionMessage(anova_result)))
} else {
  capture.output(anova_result)
}
writeLines(anova_lines, file.path(output_dir, "anova_task_type.txt"))

difference_plot <- ggplot(pairwise_df, aes(x = difference_value)) +
  geom_histogram(bins = 20, fill = "#33658A", color = "white") +
  geom_vline(xintercept = 0, linetype = "dashed", color = "#D1495B") +
  labs(
    title = "Distribution of Ensemble Minus Single Differences",
    x = "difference_value",
    y = "Count"
  ) +
  theme_minimal(base_size = 12)

box_plot <- ggplot(pairwise_df, aes(x = task_type, y = difference_value, fill = task_type)) +
  geom_boxplot(alpha = 0.8, outlier.shape = 21) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "#D1495B") +
  labs(
    title = "Difference by Task Type",
    x = "task_type",
    y = "difference_value"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "none")

ggsave(
  filename = file.path(output_dir, "difference_histogram.png"),
  plot = difference_plot,
  width = 8,
  height = 5,
  dpi = 150
)

ggsave(
  filename = file.path(output_dir, "difference_boxplot_by_task.png"),
  plot = box_plot,
  width = 8,
  height = 5,
  dpi = 150
)

cat(sprintf("Wrote analysis outputs to %s\n", output_dir))
