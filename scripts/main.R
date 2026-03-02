#!/usr/bin/env Rscript

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

if (!is.null(args$task_filter)) {
  cfg$tasks <- Filter(function(t) t$name == args$task_filter, cfg$tasks)
}

run_ctx <- init_run_context(cfg, args$output_dir)
log_event(run_ctx, "info", "run_start", list(run_id = run_ctx$run_id))

model_runs <- list()
pairwise_rows <- list()

stop_with_report <- function(msg, context = list()) {
  log_event(run_ctx, "error", "fatal", c(list(message = msg), context))
  write_error_report(run_ctx, msg, context)
  write_warnings_reports(run_ctx)
  write_partial_outputs(run_ctx, model_runs, pairwise_rows)
  stop(msg, call. = FALSE)
}

for (task in cfg$tasks) {
  log_event(run_ctx, "info", "task_start", list(task = task$name))
  for (ds in task$datasets) {
    log_event(run_ctx, "info", "dataset_start", list(task = task$name, dataset = ds$id))
    dataset <- tryCatch(load_dataset(ds, run_ctx), error = function(e) e)
    if (inherits(dataset, "error")) {
      stop_with_report(dataset$message, list(task = task$name, dataset = ds$id, stage = "load"))
    }

    dataset <- tryCatch(prepare_dataset_for_task(task$name, dataset, ds), error = function(e) e)
    if (inherits(dataset, "error")) {
      stop_with_report(dataset$message, list(task = task$name, dataset = ds$id, stage = "prepare"))
    }

    splits <- tryCatch(make_splits(task$name, dataset, task$split), error = function(e) e)
    if (inherits(splits, "error")) {
      stop_with_report(splits$message, list(task = task$name, dataset = ds$id, stage = "split"))
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
        stop_with_report(
          split_eval$message,
          list(task = task$name, dataset = ds$id, fold = sp$fold, repeat_id = sp$repeat_id, stage = "train_eval_models")
        )
      }

      model_runs <- c(model_runs, split_eval$model_rows)

      for (pair in task$model_pairs) {
        log_event(run_ctx, "info", "pair_start", list(task = task$name, dataset = ds$id, single = pair$single, ensemble = pair$ensemble, fold = sp$fold, repeat_id = sp$repeat_id))

        pair_result <- tryCatch(
          build_pair_rows_from_cache(task, ds, pair, sp, split_eval$model_cache, run_ctx),
          error = function(e) e
        )

        if (inherits(pair_result, "error")) {
          stop_with_report(
            pair_result$message,
            list(task = task$name, dataset = ds$id, single = pair$single, ensemble = pair$ensemble, fold = sp$fold, repeat_id = sp$repeat_id, stage = "build_pair_rows")
          )
        }

        pairwise_rows <- c(pairwise_rows, pair_result)
      }
    }
  }
}

write_outputs(run_ctx, model_runs, pairwise_rows)
write_warnings_reports(run_ctx)
log_event(run_ctx, "info", "run_complete", list(model_run_rows = length(model_runs), pairwise_rows = length(pairwise_rows)))
