#!/usr/bin/env Rscript

`%||%` <- function(a, b) if (is.null(a)) b else a

if (!requireNamespace("dplyr", quietly = TRUE)) stop("Package 'dplyr' required for statistical analysis")
if (!requireNamespace("ggplot2", quietly = TRUE)) stop("Package 'ggplot2' required for plotting")
if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Package 'jsonlite' required for output")

source("scripts/R/analysis_statistical.R")

args <- commandArgs(trailingOnly = TRUE)

INPUT_CSV <- if (length(args) >= 1) args[1] else "outputs/combined_pairwise_differences.csv"
OUTPUT_DIR <- if (length(args) >= 2) args[2] else "outputs/analysis"
TASK_FILTER <- if (length(args) >= 3) args[3] else NULL
METRIC_FILTER <- if (length(args) >= 4) args[4] else NULL

cat("=== TPSM Statistical Analysis ===\n\n")
cat("Input: ", INPUT_CSV, "\n")
cat("Output directory: ", OUTPUT_DIR, "\n")
if (!is.null(TASK_FILTER)) cat("Task filter: ", TASK_FILTER, "\n")
if (!is.null(METRIC_FILTER)) cat("Metric filter: ", METRIC_FILTER, "\n")

if (!file.exists(INPUT_CSV)) {
  stop("Input file not found: ", INPUT_CSV)
}

cat("\nLoading data...\n")
df <- read.csv(INPUT_CSV, stringsAsFactors = FALSE)

dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

stat_results <- perform_statistical_tests(df)

output_file <- file.path(OUTPUT_DIR, "statistical_results.csv")
write.csv(stat_results, output_file, row.names = FALSE)
cat("\n>>> Statistical results written to:", output_file, "\n")

tasks <- unique(stat_results$task_type)

for (task_type in tasks) {
  task_metrics <- unique(stat_results$metric_name[stat_results$task_type == task_type])
  if (!is.null(METRIC_FILTER)) {
    task_metrics <- task_metrics[task_metrics == METRIC_FILTER]
  }
  
  for (metric in task_metrics) {
    cat("\nGenerating plots for:", task_type, "-", metric, "\n")
    tryCatch({
      forest_file <- create_forest_plot(df, OUTPUT_DIR, task_type, metric)
      cat("  Forest plot:", forest_file, "\n")
      
      violin_file <- create_violin_plot(df, OUTPUT_DIR, task_type, metric)
      cat("  Violin plot:", violin_file, "\n")
    }, error = function(e) {
      cat("  Error generating plot:", e$message, "\n")
    })
  }
}

cat("\n=== Analysis Complete ===\n")
