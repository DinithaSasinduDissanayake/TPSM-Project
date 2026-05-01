#!/usr/bin/env Rscript

# Phase 2A Step 2: Basic descriptive summaries.
# This script does not run hypothesis tests or calculate p-values.

args <- commandArgs(trailingOnly = TRUE)

DATA_PATH <- if (length(args) >= 1) {
  args[1]
} else {
  "outputs/archive/legacy/py_full_no_timeseries_probe/20260421T231947/analysis_ready_pairwise.csv"
}

OUTPUT_DIR <- if (length(args) >= 2) {
  args[2]
} else {
  "outputs/final_project_analysis/02_descriptive_summaries"
}

STEP1_DIR <- if (length(args) >= 3) {
  args[3]
} else {
  "outputs/final_project_analysis/01_data_understanding"
}

if (!file.exists(DATA_PATH)) {
  stop(paste("Input CSV not found:", DATA_PATH))
}

if (!dir.exists(STEP1_DIR)) {
  warning(paste("Step 1 output folder not found:", STEP1_DIR))
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

df <- read.csv(DATA_PATH, stringsAsFactors = FALSE)

if ("valid_pair" %in% names(df)) {
  df$valid_pair <- normalize_bool(df$valid_pair)
}

if ("ensemble_better" %in% names(df)) {
  df$ensemble_better <- normalize_bool(df$ensemble_better)
}

required_columns <- c(
  "task_type",
  "dataset_id",
  "metric_name",
  "model_pair",
  "difference_value",
  "ensemble_better",
  "valid_pair"
)

missing_columns <- setdiff(required_columns, names(df))
if (length(missing_columns) > 0) {
  stop(paste("Required columns missing:", paste(missing_columns, collapse = ", ")))
}

# Keep valid rows only. This should keep all rows for the recovered dataset.
df <- df[df$valid_pair == TRUE & !is.na(df$valid_pair), ]

df$win_status <- ifelse(
  df$difference_value > 0,
  "ensemble_win",
  ifelse(df$difference_value < 0, "single_win", "tie")
)

summarise_block <- function(data) {
  data.frame(
    comparison_count = nrow(data),
    ensemble_wins = sum(data$win_status == "ensemble_win", na.rm = TRUE),
    single_wins = sum(data$win_status == "single_win", na.rm = TRUE),
    ties = sum(data$win_status == "tie", na.rm = TRUE),
    ensemble_win_rate = round(mean(data$win_status == "ensemble_win", na.rm = TRUE), 4),
    mean_difference = round(mean(data$difference_value, na.rm = TRUE), 6),
    median_difference = round(median(data$difference_value, na.rm = TRUE), 6),
    sd_difference = round(sd(data$difference_value, na.rm = TRUE), 6),
    min_difference = round(min(data$difference_value, na.rm = TRUE), 6),
    max_difference = round(max(data$difference_value, na.rm = TRUE), 6)
  )
}

write_group_summary <- function(data, group_columns, output_file) {
  grouped <- split(data, data[group_columns], drop = TRUE)
  rows <- lapply(names(grouped), function(group_name) {
    group_data <- grouped[[group_name]]
    group_values <- group_data[1, group_columns, drop = FALSE]
    cbind(group_values, summarise_block(group_data), row.names = NULL)
  })
  out <- do.call(rbind, rows)
  out <- out[order(out$ensemble_win_rate, decreasing = TRUE), ]
  write.csv(out, file.path(OUTPUT_DIR, output_file), row.names = FALSE)
  out
}

cat("=== TPSM Phase 2A Step 2: Descriptive Summaries ===\n")
cat("Input:", DATA_PATH, "\n")
cat("Step 1 context:", STEP1_DIR, "\n")
cat("Output:", OUTPUT_DIR, "\n\n")

overall <- cbind(
  data.frame(
    row_count = nrow(df),
    dataset_count = length(unique(df$dataset_id)),
    task_count = length(unique(df$task_type)),
    metric_count = length(unique(df$metric_name)),
    model_pair_count = length(unique(df$model_pair))
  ),
  summarise_block(df)
)

write.csv(
  overall,
  file.path(OUTPUT_DIR, "overall_descriptive_summary.csv"),
  row.names = FALSE
)

summary_by_task_type <- write_group_summary(
  df,
  "task_type",
  "summary_by_task_type.csv"
)

summary_by_dataset <- write_group_summary(
  df,
  "dataset_id",
  "summary_by_dataset.csv"
)

summary_by_metric <- write_group_summary(
  df,
  "metric_name",
  "summary_by_metric.csv"
)

summary_by_model_pair <- write_group_summary(
  df,
  "model_pair",
  "summary_by_model_pair.csv"
)

summary_by_task_and_metric <- write_group_summary(
  df,
  c("task_type", "metric_name"),
  "summary_by_task_and_metric.csv"
)

top_datasets <- head(summary_by_dataset, 5)
bottom_datasets <- head(summary_by_dataset[order(summary_by_dataset$ensemble_win_rate), ], 5)
top_metrics <- head(summary_by_metric, 3)
bottom_metrics <- head(summary_by_metric[order(summary_by_metric$ensemble_win_rate), ], 3)
top_pairs <- head(summary_by_model_pair, 3)
bottom_pairs <- head(summary_by_model_pair[order(summary_by_model_pair$ensemble_win_rate), ], 3)

mape_row <- summary_by_metric[summary_by_metric$metric_name == "mape", ]
tie_count <- overall$ties[1]

notes_path <- file.path(OUTPUT_DIR, "descriptive_summary_notes.md")

notes <- c(
  "# Phase 2A Step 2: Descriptive Summaries",
  "",
  paste("Input CSV:", DATA_PATH),
  paste("Step 1 context folder:", STEP1_DIR),
  "",
  "## Overall Pattern",
  "",
  paste("- Total valid comparison rows:", overall$row_count[1]),
  paste("- Datasets:", overall$dataset_count[1]),
  paste("- Task types:", overall$task_count[1]),
  paste("- Metrics:", overall$metric_count[1]),
  paste("- Model pairs:", overall$model_pair_count[1]),
  paste("- Ensemble wins:", overall$ensemble_wins[1]),
  paste("- Single-model wins:", overall$single_wins[1]),
  paste("- Ties:", tie_count),
  paste("- Ensemble win rate:", paste0(round(overall$ensemble_win_rate[1] * 100, 2), "%")),
  paste("- Mean difference_value:", overall$mean_difference[1]),
  paste("- Median difference_value:", overall$median_difference[1]),
  "",
  "This is descriptive analysis only. These values describe the generated comparison rows; they are not hypothesis-test results.",
  "",
  "## Task Types",
  "",
  paste(
    apply(summary_by_task_type, 1, function(row) {
      paste0(
        "- ", row[["task_type"]], ": ",
        row[["comparison_count"]], " comparisons, ",
        round(as.numeric(row[["ensemble_win_rate"]]) * 100, 2), "% ensemble win rate"
      )
    }),
    collapse = "\n"
  ),
  "",
  "## Datasets That Stand Out",
  "",
  "Highest ensemble win rates:",
  paste(
    apply(top_datasets, 1, function(row) {
      paste0("- ", row[["dataset_id"]], ": ", round(as.numeric(row[["ensemble_win_rate"]]) * 100, 2), "%")
    }),
    collapse = "\n"
  ),
  "",
  "Lowest ensemble win rates:",
  paste(
    apply(bottom_datasets, 1, function(row) {
      paste0("- ", row[["dataset_id"]], ": ", round(as.numeric(row[["ensemble_win_rate"]]) * 100, 2), "%")
    }),
    collapse = "\n"
  ),
  "",
  "## Metrics That Stand Out",
  "",
  "Highest ensemble win rates:",
  paste(
    apply(top_metrics, 1, function(row) {
      paste0("- ", row[["metric_name"]], ": ", round(as.numeric(row[["ensemble_win_rate"]]) * 100, 2), "%")
    }),
    collapse = "\n"
  ),
  "",
  "Lowest ensemble win rates:",
  paste(
    apply(bottom_metrics, 1, function(row) {
      paste0("- ", row[["metric_name"]], ": ", round(as.numeric(row[["ensemble_win_rate"]]) * 100, 2), "%")
    }),
    collapse = "\n"
  ),
  "",
  "## Model Pairs That Stand Out",
  "",
  "Highest ensemble win rates:",
  paste(
    apply(top_pairs, 1, function(row) {
      paste0("- ", row[["model_pair"]], ": ", round(as.numeric(row[["ensemble_win_rate"]]) * 100, 2), "%")
    }),
    collapse = "\n"
  ),
  "",
  "Lowest ensemble win rates:",
  paste(
    apply(bottom_pairs, 1, function(row) {
      paste0("- ", row[["model_pair"]], ": ", round(as.numeric(row[["ensemble_win_rate"]]) * 100, 2), "%")
    }),
    collapse = "\n"
  ),
  "",
  "## Cautions",
  "",
  paste("- Ties are counted separately. They are not counted as ensemble wins. Tie count:", tie_count),
  if (nrow(mape_row) > 0) {
    paste0(
      "- MAPE is present with ", mape_row$comparison_count[1],
      " rows and should be treated carefully because Step 1 and generator warnings flagged low-target MAPE risk."
    )
  } else {
    "- MAPE is not present in this descriptive dataset."
  },
  "- Descriptive win rates do not prove the claim. They only show patterns that should be checked later.",
  "",
  "## Questions For The Next Step",
  "",
  "- Which patterns are easiest to explain visually?",
  "- Should MAPE be excluded from the main visual story and kept as a caution/sensitivity item?",
  "- Do task types, metrics, or model pairs show noticeably different behavior?",
  "- Which grouped summaries should be turned into simple plots in Step 3?"
)

writeLines(notes, notes_path)

cat("Files written to:", OUTPUT_DIR, "\n")
cat("- overall_descriptive_summary.csv\n")
cat("- summary_by_task_type.csv\n")
cat("- summary_by_dataset.csv\n")
cat("- summary_by_metric.csv\n")
cat("- summary_by_model_pair.csv\n")
cat("- summary_by_task_and_metric.csv\n")
cat("- descriptive_summary_notes.md\n")
