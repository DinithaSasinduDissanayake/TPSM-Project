#!/usr/bin/env Rscript

`%||%` <- function(a, b) if (is.null(a)) b else a

source("scripts/R/config.R")
source("scripts/R/logging.R")
source("scripts/R/load_data.R")
source("scripts/R/splits.R")
source("scripts/R/models_classification.R")
source("scripts/R/models_regression.R")
source("scripts/R/models_timeseries.R")
source("scripts/R/metrics.R")
source("scripts/R/pairwise_builder.R")
source("scripts/R/writer.R")

args <- parse_args(commandArgs(trailingOnly = TRUE))
cfg <- get_config()

stop_on_fail <- cfg$stop_on_first_fail

if (!is.null(args$task_filter)) {
  cfg$tasks <- Filter(function(t) t$name == args$task_filter, cfg$tasks)
}

run_ctx <- init_run_context(cfg, args$output_dir)
log_event(run_ctx, "info", "run_start", list(run_id = run_ctx$run_id, stop_on_fail = stop_on_fail))

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

for (task in cfg$tasks) {
  log_event(run_ctx, "info", "task_start", list(task = task$name))
  for (ds in task$datasets) {
    log_event(run_ctx, "info", "dataset_start", list(task = task$name, dataset = ds$id))
    dataset <- tryCatch(load_dataset(ds, run_ctx), error = function(e) e)
    if (inherits(dataset, "error")) {
      handle_error(dataset$message, list(task = task$name, dataset = ds$id, stage = "load"))
      next
    }

    dataset <- tryCatch(prepare_dataset_for_task(task$name, dataset, ds), error = function(e) e)
    if (inherits(dataset, "error")) {
      handle_error(dataset$message, list(task = task$name, dataset = ds$id, stage = "prepare"))
      next
    }

    splits <- tryCatch(make_splits(task$name, dataset, task$split, ds$target), error = function(e) e)
    if (inherits(splits, "error")) {
      handle_error(splits$message, list(task = task$name, dataset = ds$id, stage = "split"))
      next
    }

    model_names <- unique(c(
      vapply(task$model_pairs, function(p) p$single, character(1)),
      vapply(task$model_pairs, function(p) p$ensemble, character(1))
    ))

    for (sp in splits) {
      split_eval <- tryCatch(
        evaluate_models_on_split(task, dataset, ds, sp, model_names, run_ctx),
        error = function(e) e
      )

      if (inherits(split_eval, "error")) {
        handle_error(
          split_eval$message,
          list(task = task$name, dataset = ds$id, fold = sp$fold, repeat_id = sp$repeat_id, stage = "train_eval_models")
        )
        next
      }

      model_runs <- c(model_runs, split_eval$model_rows)

      for (pair in task$model_pairs) {
        log_event(run_ctx, "info", "pair_start", list(task = task$name, dataset = ds$id, single = pair$single, ensemble = pair$ensemble, fold = sp$fold, repeat_id = sp$repeat_id))

        pair_result <- tryCatch(
          build_pair_rows_from_cache(task, ds, pair, sp, split_eval$model_cache, run_ctx),
          error = function(e) e
        )

        if (inherits(pair_result, "error")) {
          handle_error(
            pair_result$message,
            list(task = task$name, dataset = ds$id, single = pair$single, ensemble = pair$ensemble, fold = sp$fold, repeat_id = sp$repeat_id, stage = "build_pair_rows")
          )
          next
        }

        pairwise_rows <- c(pairwise_rows, pair_result)
      }
    }
  }
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
  log_event(run_ctx, "info", "run_complete", list(model_run_rows = length(model_runs), pairwise_rows = length(pairwise_rows)))
}
