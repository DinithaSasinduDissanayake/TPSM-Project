#!/usr/bin/env Rscript

# Phase 2A Step 1: Data understanding / analysis-readiness check.
# This script only inspects the generated comparison CSV structure.

args <- commandArgs(trailingOnly = TRUE)

DATA_PATH <- if (length(args) >= 1) {
  args[1]
} else {
  "outputs/archive/legacy/py_full_no_timeseries_probe/20260421T231947/analysis_ready_pairwise.csv"
}

OUTPUT_DIR <- if (length(args) >= 2) {
  args[2]
} else {
  "outputs/final_project_analysis/01_data_understanding"
}

if (!file.exists(DATA_PATH)) {
  stop(paste("Input CSV not found:", DATA_PATH))
}

if (!dir.exists(OUTPUT_DIR)) {
  dir.create(OUTPUT_DIR, recursive = TRUE)
}

df <- read.csv(DATA_PATH, stringsAsFactors = FALSE)

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

if ("valid_pair" %in% names(df)) {
  df$valid_pair <- normalize_bool(df$valid_pair)
}

if ("ensemble_better" %in% names(df)) {
  df$ensemble_better <- normalize_bool(df$ensemble_better)
}

cat("=== TPSM Phase 2A Step 1: Data Understanding ===\n")
cat("Input:", DATA_PATH, "\n")
cat("Output:", OUTPUT_DIR, "\n\n")

# 1. Basic dimensions ---------------------------------------------------------

basic_structure <- data.frame(
  item = c("input_file", "row_count", "column_count"),
  value = c(DATA_PATH, nrow(df), ncol(df)),
  stringsAsFactors = FALSE
)

write.csv(
  basic_structure,
  file.path(OUTPUT_DIR, "basic_structure.csv"),
  row.names = FALSE
)

cat("Rows:", nrow(df), "\n")
cat("Columns:", ncol(df), "\n\n")

# 2. Column names and data types ---------------------------------------------

column_info <- data.frame(
  column_name = names(df),
  data_type = sapply(df, class),
  stringsAsFactors = FALSE
)

write.csv(
  column_info,
  file.path(OUTPUT_DIR, "column_info.csv"),
  row.names = FALSE
)

# 3. First few rows -----------------------------------------------------------

first_rows <- head(df, 10)
write.csv(
  first_rows,
  file.path(OUTPUT_DIR, "first_10_rows.csv"),
  row.names = FALSE
)

# 4. Missing values -----------------------------------------------------------

missing_values <- data.frame(
  column_name = names(df),
  missing_count = sapply(df, function(x) sum(is.na(x))),
  missing_percent = round(sapply(df, function(x) mean(is.na(x)) * 100), 2),
  stringsAsFactors = FALSE
)

write.csv(
  missing_values,
  file.path(OUTPUT_DIR, "missing_values_by_column.csv"),
  row.names = FALSE
)

# 5. Duplicate rows -----------------------------------------------------------

duplicate_summary <- data.frame(
  item = c("duplicate_rows", "unique_rows"),
  value = c(sum(duplicated(df)), nrow(unique(df))),
  stringsAsFactors = FALSE
)

write.csv(
  duplicate_summary,
  file.path(OUTPUT_DIR, "duplicate_rows_summary.csv"),
  row.names = FALSE
)

# 6. Simple count tables ------------------------------------------------------

write_count_table <- function(data, column_name, output_file) {
  if (!column_name %in% names(data)) {
    out <- data.frame(value = character(), count = integer())
  } else {
    out <- as.data.frame(table(data[[column_name]], useNA = "ifany"))
    names(out) <- c("value", "count")
    out <- out[order(out$count, decreasing = TRUE), ]
  }
  write.csv(out, file.path(OUTPUT_DIR, output_file), row.names = FALSE)
  out
}

task_type_counts <- write_count_table(df, "task_type", "counts_task_type.csv")
dataset_counts <- write_count_table(df, "dataset_id", "counts_dataset_id.csv")
metric_counts <- write_count_table(df, "metric_name", "counts_metric_name.csv")
model_pair_counts <- write_count_table(df, "model_pair", "counts_model_pair.csv")
fold_counts <- write_count_table(df, "fold", "counts_fold.csv")
repeat_counts <- write_count_table(df, "repeat_id", "counts_repeat_id.csv")
valid_pair_counts <- write_count_table(df, "valid_pair", "counts_valid_pair.csv")

# 7. Readiness checks ---------------------------------------------------------

has_time_series <- "task_type" %in% names(df) && any(df$task_type == "timeseries")
all_valid_pairs <- "valid_pair" %in% names(df) && all(df$valid_pair == TRUE)

required_columns <- c(
  "difference_value",
  "ensemble_better",
  "single_metric_value",
  "ensemble_metric_value"
)

required_column_check <- data.frame(
  column_name = required_columns,
  exists = required_columns %in% names(df),
  missing_count = sapply(required_columns, function(col) {
    if (col %in% names(df)) sum(is.na(df[[col]])) else NA_integer_
  }),
  stringsAsFactors = FALSE
)

numeric_columns <- c(
  "difference_value",
  "single_metric_value",
  "ensemble_metric_value"
)

numeric_usability <- data.frame(
  column_name = numeric_columns,
  exists = numeric_columns %in% names(df),
  is_numeric = sapply(numeric_columns, function(col) {
    col %in% names(df) && is.numeric(df[[col]])
  }),
  missing_count = sapply(numeric_columns, function(col) {
    if (col %in% names(df)) sum(is.na(df[[col]])) else NA_integer_
  }),
  stringsAsFactors = FALSE
)

ensemble_better_usable <- "ensemble_better" %in% names(df) &&
  all(df$ensemble_better %in% c(TRUE, FALSE))

difference_sign_mismatch <- if (
  all(c("difference_value", "ensemble_better") %in% names(df))
) {
  sum((df$difference_value > 0) != df$ensemble_better)
} else {
  NA_integer_
}

readiness_checks <- data.frame(
  check = c(
    "time_series_rows_exist",
    "all_valid_pair_values_are_true",
    "ensemble_better_is_boolean",
    "difference_sign_matches_ensemble_better_except_ties",
    "numeric_metric_columns_are_numeric",
    "required_columns_exist"
  ),
  result = c(
    has_time_series,
    all_valid_pairs,
    ensemble_better_usable,
    difference_sign_mismatch == 0,
    all(numeric_usability$is_numeric),
    all(required_column_check$exists)
  ),
  detail = c(
    paste("time_series_rows =", sum(df$task_type == "timeseries")),
    paste("valid_pair_false_or_missing =", sum(df$valid_pair != TRUE | is.na(df$valid_pair))),
    paste("unique values =", paste(unique(df$ensemble_better), collapse = ", ")),
    paste("mismatch_count =", difference_sign_mismatch),
    paste("checked columns =", paste(numeric_columns, collapse = ", ")),
    paste("checked columns =", paste(required_columns, collapse = ", "))
  ),
  stringsAsFactors = FALSE
)

write.csv(
  required_column_check,
  file.path(OUTPUT_DIR, "required_column_check.csv"),
  row.names = FALSE
)

write.csv(
  numeric_usability,
  file.path(OUTPUT_DIR, "numeric_usability_check.csv"),
  row.names = FALSE
)

write.csv(
  readiness_checks,
  file.path(OUTPUT_DIR, "readiness_checks.csv"),
  row.names = FALSE
)

# 8. Beginner-friendly markdown notes ----------------------------------------

note_path <- file.path(OUTPUT_DIR, "data_understanding_notes.md")

notes <- c(
  "# Phase 2A Step 1: Data Understanding",
  "",
  paste("Input CSV:", DATA_PATH),
  "",
  "## What This File Contains",
  "",
  paste("- Rows:", nrow(df)),
  paste("- Columns:", ncol(df)),
  paste("- Task types:", paste(task_type_counts$value, collapse = ", ")),
  paste("- Number of datasets:", nrow(dataset_counts)),
  paste("- Number of metrics:", nrow(metric_counts)),
  paste("- Number of model pairs:", nrow(model_pair_counts)),
  "",
  "Each row is one generated paired comparison between a single model and an ensemble model.",
  "The row is tied to a task type, dataset, fold, repeat, model pair, and metric.",
  "",
  "## Readiness Checks",
  "",
  paste("- Time series rows present:", has_time_series),
  paste("- All valid_pair values are TRUE:", all_valid_pairs),
  paste("- Duplicate rows:", sum(duplicated(df))),
  paste("- Missing values outside notes column:", sum(missing_values$missing_count[missing_values$column_name != "notes"])),
  paste("- Required analysis columns exist:", all(required_column_check$exists)),
  paste("- Numeric metric columns are numeric:", all(numeric_usability$is_numeric)),
  paste("- difference_value / ensemble_better mismatch count:", difference_sign_mismatch),
  "",
  "## What We Learned",
  "",
  "- The dataset is already in analysis-ready table form.",
  "- Classification and regression rows are present.",
  "- This Step 1 script only checks structure and usability.",
  "- Deeper descriptive summaries, plots, and hypothesis testing should be done in later steps.",
  "",
  "## Notes",
  "",
  "- The `notes` column can be mostly empty. That is acceptable because it only stores special warnings.",
  "- A mismatch where `difference_value` is exactly zero should be treated as a tie in later analysis.",
  "- Do not treat this file as raw source data. It is generated comparison data."
)

writeLines(notes, note_path)

cat("Files written to:", OUTPUT_DIR, "\n")
cat("- basic_structure.csv\n")
cat("- column_info.csv\n")
cat("- first_10_rows.csv\n")
cat("- missing_values_by_column.csv\n")
cat("- duplicate_rows_summary.csv\n")
cat("- counts_task_type.csv\n")
cat("- counts_dataset_id.csv\n")
cat("- counts_metric_name.csv\n")
cat("- counts_model_pair.csv\n")
cat("- counts_fold.csv\n")
cat("- counts_repeat_id.csv\n")
cat("- counts_valid_pair.csv\n")
cat("- required_column_check.csv\n")
cat("- numeric_usability_check.csv\n")
cat("- readiness_checks.csv\n")
cat("- data_understanding_notes.md\n")
