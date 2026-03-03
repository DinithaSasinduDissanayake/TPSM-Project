#!/usr/bin/env Rscript

`%||%` <- function(a, b) if (is.null(a)) b else a

source("scripts/R/config.R")
source("scripts/R/logging.R")
source("scripts/R/validation.R")
source("scripts/R/load_data.R")
source("scripts/R/splits.R")
source("scripts/R/models_classification.R")
source("scripts/R/models_regression.R")
source("scripts/R/models_timeseries.R")
source("scripts/R/metrics.R")
source("scripts/R/pairwise_builder.R")
source("scripts/R/writer.R")
source("scripts/R/parallel_utils.R")

args <- parse_args(commandArgs(trailingOnly = TRUE))
cfg <- get_config(args$config_path %||% NULL)

validate_config(cfg)

stop_on_fail <- cfg$stop_on_first_fail
timeout_sec <- cfg$timeout_seconds %||% 300
parallel_workers <- cfg$parallel_workers %||% 1
if (!is.null(args$workers)) parallel_workers <- args$workers

fast_mode <- isTRUE(args$fast)
n_cores <- NA
if (fast_mode) {
  n_cores <- parallel::detectCores(logical = TRUE)
  if (is.null(args$workers)) {
    parallel_workers <- max(1, n_cores - 2)
  }
}

if (!is.null(args$task_filter)) {
  cfg$tasks <- Filter(function(t) t$name == args$task_filter, cfg$tasks)
}

run_ctx <- init_run_context(cfg, args$output_dir)
log_event(run_ctx, "info", "run_start", list(
  run_id = run_ctx$run_id,
  stop_on_fail = stop_on_fail,
  timeout_sec = timeout_sec,
  parallel_workers = parallel_workers,
  fast_mode = fast_mode
))

future_available <- requireNamespace("future", quietly = TRUE) && requireNamespace("furrr", quietly = TRUE)
if (fast_mode && !is.na(n_cores)) {
  log_event(run_ctx, "info", "fast_mode_enabled", list(
    n_cores = n_cores,
    requested_workers = parallel_workers
  ))
}
if (parallel_workers > 1 && future_available) {
  library(future)
  library(furrr)
  plan(multisession, workers = parallel_workers)
  log_event(run_ctx, "info", "parallel_enabled", list(workers = parallel_workers))
  options(future.globals.onMissing = "ignore")
} else {
  if (parallel_workers > 1) {
    message("Packages 'future' or 'furrr' not available, running in sequential mode")
    log_event(run_ctx, "warn", "parallel_disabled", list(reason = "missing_packages"))
  }
}

model_runs <- list()
pairwise_rows <- list()
failed_datasets <- list()

handle_error <- function(msg, context = list()) {
  context_with_msg <- c(list(message = msg), context)
  log_event(run_ctx, "error", "error", context_with_msg)
  if (stop_on_fail) {
    write_error_report(run_ctx, msg, context)
    write_warnings_reports(run_ctx)
    write_partial_outputs(run_ctx, model_runs, pairwise_rows)
    stop(msg, call. = FALSE)
  } else {
    failed_datasets <<- c(failed_datasets, list(c(context_with_msg)))
    warning(msg)
  }
}

log_event(run_ctx, "info", "task_start", list(task = "ALL"))

all_dataset_results <- list()
ds_idx <- 1

for (task in cfg$tasks) {
  task_results <- list()
  
  if (parallel_workers > 1 && future_available) {
    task_results <- future_map(task$datasets, function(ds) {
      run_dataset_task(task, ds, run_ctx, stop_on_fail, timeout_sec)
    }, .options = furrr_options(seed = NULL))
  } else {
    for (ds in task$datasets) {
      log_event(run_ctx, "info", "dataset_start", list(task = task$name, dataset = ds$id))
      ds_result <- run_dataset_task(task, ds, run_ctx, stop_on_fail, timeout_sec)
      task_results[[length(task_results) + 1]] <- ds_result
    }
  }
  
  for (ds_result in task_results) {
    if (ds_result$failed) {
      handle_error(
        ds_result$error_message,
        list(task = task$name, dataset = ds_result$dataset_id, stage = "dataset")
      )
    } else {
      model_runs <- c(model_runs, ds_result$model_runs)
      pairwise_rows <- c(pairwise_rows, ds_result$pairwise_rows)
      if (!is.null(ds_result$warnings) && length(ds_result$warnings) > 0) {
        for (w in ds_result$warnings) {
          run_ctx$state$warnings[[length(run_ctx$state$warnings) + 1]] <- w
        }
      }
    }
  }
  
  all_dataset_results <- c(all_dataset_results, task_results)
}

if (parallel_workers > 1 && future_available) {
  plan(sequential)
  log_event(run_ctx, "info", "parallel_disabled", list(reason = "run_complete"))
}

write_outputs(run_ctx, model_runs, pairwise_rows)
write_warnings_reports(run_ctx)

if (length(failed_datasets) > 0) {
  failed_summary <- data.frame(
    do.call(rbind, lapply(failed_datasets, function(f) {
      data.frame(
        task = f$task %||% NA,
        dataset = f$dataset %||% NA,
        stage = f$stage %||% NA,
        fold = f$fold %||% NA,
        repeat_id = f$repeat_id %||% NA,
        message = f$message %||% NA
      )
    }))
  )
  write.csv(failed_summary, file.path(run_ctx$out_dir, "failed_datasets.csv"), row.names = FALSE)
  log_event(run_ctx, "warn", "run_with_failures", list(
    failed_count = length(failed_datasets),
    failed_summary = paste0(failed_summary$dataset, " (", failed_summary$stage, ")", collapse = "; ")
  ))
} else {
  log_event(run_ctx, "info", "run_complete", list(
    model_run_rows = length(model_runs), 
    pairwise_rows = length(pairwise_rows)
  ))
}
