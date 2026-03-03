#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

OUTPUT_DIR <- if (length(args) >= 1) args[1] else "outputs"
INPUT_DIRS <- if (length(args) >= 2) args[2] else NULL

cat("=== TPSM Pipeline Output Combiner ===\n\n")

if (!is.null(INPUT_DIRS)) {
  input_dirs <- strsplit(INPUT_DIRS, ",")[[1]]
} else {
  input_dirs <- list.dirs(OUTPUT_DIR, recursive = FALSE)
  input_dirs <- input_dirs[grepl("^\\d{8}T\\d{6}$", basename(input_dirs))]
}

cat("Found", length(input_dirs), "run directories to combine\n\n")

all_pairwise <- list()
all_model_runs <- list()

for (dir in input_dirs) {
  pw_file <- file.path(dir, "pairwise_differences.csv")
  mr_file <- file.path(dir, "model_runs.csv")
  
  if (file.exists(pw_file)) {
    cat("Reading pairwise from:", basename(dir), "\n")
    pw <- read.csv(pw_file, stringsAsFactors = FALSE)
    all_pairwise[[length(all_pairwise) + 1]] <- pw
  }
  
  if (file.exists(mr_file)) {
    mr <- read.csv(mr_file, stringsAsFactors = FALSE)
    all_model_runs[[length(all_model_runs) + 1]] <- mr
  }
}

if (length(all_pairwise) > 0) {
  combined_pw <- do.call(rbind, all_pairwise)
  combined_pw$comparison_id <- NULL
  combined_pw <- combined_pw[!duplicated(combined_pw), ]
  rownames(combined_pw) <- NULL
  
  output_file <- file.path(OUTPUT_DIR, "combined_pairwise_differences.csv")
  write.csv(combined_pw, output_file, row.names = FALSE)
  cat("\n>>> Combined", nrow(combined_pw), "pairwise rows ->", output_file, "\n")
} else {
  cat("No pairwise_differences.csv files found\n")
}

if (length(all_model_runs) > 0) {
  combined_mr <- do.call(rbind, all_model_runs)
  combined_mr$run_id <- NULL
  combined_mr <- combined_mr[!duplicated(combined_mr), ]
  rownames(combined_mr) <- NULL
  
  output_file <- file.path(OUTPUT_DIR, "combined_model_runs.csv")
  write.csv(combined_mr, output_file, row.names = FALSE)
  cat(">>> Combined", nrow(combined_mr), "model runs ->", output_file, "\n")
}

cat("\n=== Combine Complete ===\n")
