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

# Flatten all (task, dataset) pairs into single job pool for better CPU utilization
all_jobs <- list()
for (task in cfg$tasks) {
  for (ds in task$datasets) {
    all_jobs[[length(all_jobs) + 1]] <- list(task = task, ds = ds)
  }
}

all_dataset_results <- list()

if (parallel_workers > 1 && future_available) {
  all_dataset_results <- future_map(all_jobs, function(job) {
    tryCatch(
      run_dataset_task(job$task, job$ds, run_ctx, stop_on_fail, timeout_sec),
      error = function(e) {
        list(
          dataset_id = job$ds$id,
          task_name = job$task$name,
          model_runs = list(),
          pairwise_rows = list(),
          warnings = list(),
          failed = TRUE,
          error_message = paste0("worker_crash: ", e$message)
        )
      }
    )
  }, .options = furrr_options(seed = NULL))
} else {
  for (job in all_jobs) {
    log_event(run_ctx, "info", "dataset_start", list(task = job$task$name, dataset = job$ds$id))
    ds_result <- tryCatch(
      run_dataset_task(job$task, job$ds, run_ctx, stop_on_fail, timeout_sec),
      error = function(e) {
        list(
          dataset_id = job$ds$id,
          task_name = job$task$name,
          model_runs = list(),
          pairwise_rows = list(),
          warnings = list(),
          failed = TRUE,
          error_message = paste0("unhandled: ", e$message)
        )
      }
    )
    all_dataset_results[[length(all_dataset_results) + 1]] <- ds_result
  }
}

total_datasets <- length(all_dataset_results)
for (i in seq_along(all_dataset_results)) {
  ds_result <- all_dataset_results[[i]]
  tryCatch({
    if (ds_result$failed) {
      handle_error(
        ds_result$error_message,
        list(task = ds_result$task_name, dataset = ds_result$dataset_id, stage = "dataset")
      )
      log_event(run_ctx, "info", "progress", list(
        completed = i,
        total = total_datasets,
        pct = round(100 * i / total_datasets, 1),
        last_dataset = ds_result$dataset_id,
        last_status = "failed"
      ))
    } else {
      model_runs <- c(model_runs, ds_result$model_runs)
      pairwise_rows <- c(pairwise_rows, ds_result$pairwise_rows)
      if (!is.null(ds_result$warnings) && length(ds_result$warnings) > 0) {
        for (w in ds_result$warnings) {
          run_ctx$state$warnings[[length(run_ctx$state$warnings) + 1]] <- w
        }
      }
      log_event(run_ctx, "info", "progress", list(
        completed = i,
        total = total_datasets,
        pct = round(100 * i / total_datasets, 1),
        last_dataset = ds_result$dataset_id,
        last_status = "success",
        n_model_runs = length(ds_result$model_runs),
        n_pairwise_rows = length(ds_result$pairwise_rows)
      ))
    }
  }, error = function(e) {
    log_event(run_ctx, "error", "result_processing_error", list(
      dataset = ds_result$dataset_id,
      message = e$message
    ))
  })

  # Write partial outputs after every 5 datasets (crash protection)
  if (i %% 5 == 0 || i == total_datasets) {
    tryCatch(
      write_partial_outputs(run_ctx, model_runs, pairwise_rows),
      error = function(e) {}
    )
  }
}

if (parallel_workers > 1 && future_available) {
  plan(sequential)
  log_event(run_ctx, "info", "parallel_disabled", list(reason = "run_complete"))
}

run_end_time <- Sys.time()
run_start_time <- as.POSIXct(run_ctx$run_id, format = "%Y%m%dT%H%M%S")
run_elapsed_sec <- as.numeric(difftime(run_end_time, run_start_time, units = "secs"))

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
  log_event(run_ctx, "info", "run_summary", list(
    elapsed_sec = run_elapsed_sec,
    elapsed_min = round(run_elapsed_sec / 60, 2),
    total_datasets = total_datasets,
    successful_datasets = total_datasets - length(failed_datasets),
    failed_datasets = length(failed_datasets),
    model_run_rows = length(model_runs),
    pairwise_rows = length(pairwise_rows),
    total_warnings = length(run_ctx$state$warnings),
    run_id = run_ctx$run_id,
    output_dir = run_ctx$out_dir
  ))
} else {
  log_event(run_ctx, "info", "run_complete", list(
    model_run_rows = length(model_runs), 
    pairwise_rows = length(pairwise_rows)
  ))
  log_event(run_ctx, "info", "run_summary", list(
    elapsed_sec = run_elapsed_sec,
    elapsed_min = round(run_elapsed_sec / 60, 2),
    total_datasets = total_datasets,
    successful_datasets = total_datasets,
    failed_datasets = 0,
    model_run_rows = length(model_runs),
    pairwise_rows = length(pairwise_rows),
    total_warnings = length(run_ctx$state$warnings),
    run_id = run_ctx$run_id,
    output_dir = run_ctx$out_dir
  ))
}
