get_base_seed <- function(dataset_id = NULL, base = 42) {
  if (!is.null(dataset_id)) {
    base + sum(as.numeric(charToRaw(dataset_id))) %% 100000
  } else {
    base
  }
}

make_split_seed <- function(base_seed, repeat_id, fold) {
  base_seed + (repeat_id - 1) * 1000 + fold
}

with_timeout <- function(expr, timeout = 300, on_timeout = "error") {
  if (!requireNamespace("R.utils", quietly = TRUE)) {
    warning("R.utils not available — timeout protection disabled")
    return(expr)
  }
  tryCatch({
    R.utils::withTimeout(expr, timeout = timeout, onTimeout = on_timeout)
  }, TimeoutException = function(e) {
    if (on_timeout == "error") {
      stop(sprintf("Operation timed out after %d seconds", timeout), call. = FALSE)
    }
    NULL
  })
}

download_with_retry <- function(url, dest, max_retries = 3, timeout = 60) {
  for (i in seq_len(max_retries)) {
    tryCatch({
      utils::download.file(url, dest, mode = "wb", quiet = TRUE, timeout = timeout)
      if (file.info(dest)$size > 100) {
        first_bytes <- readBin(dest, raw(), n = min(200, file.info(dest)$size))
        first_str <- tryCatch(
          rawToChar(first_bytes),
          error = function(e) ""
        )
        if (grepl("<!DOCTYPE|<html|<HTML", first_str, ignore.case = TRUE)) {
          message(sprintf("Downloaded HTML error page instead of data from %s", url))
          unlink(dest)
          if (i < max_retries) {
            wait_time <- 2^i
            message(sprintf("Retrying in %d seconds...", wait_time))
            Sys.sleep(wait_time)
          }
          next
        }
        return(TRUE)
      }
    }, error = function(e) {
      message(sprintf("Download attempt %d failed: %s", i, e$message))
    })
    if (i < max_retries) {
      wait_time <- 2^i
      message(sprintf("Retrying in %d seconds...", wait_time))
      Sys.sleep(wait_time)
    }
  }
  FALSE
}

run_dataset_task <- function(task, ds, run_ctx, stop_on_fail, timeout_sec) {
  result <- list(
    dataset_id = ds$id,
    task_name = task$name,
    model_runs = list(),
    pairwise_rows = list(),
    warnings = list(),
    failed = FALSE,
    error_message = NULL
  )

  write_heartbeat(run_ctx, ds$id)
  run_ctx$state$last_dataset <<- ds$id

  dataset_start_time <- Sys.time()
  log_event(run_ctx, "info", "dataset_start", list(
    task = task$name,
    dataset = ds$id,
    n_workers = if (exists("parallel_workers")) get("parallel_workers", envir = globalenv()) else 1
  ))

  load_start <- Sys.time()
  dataset <- tryCatch(
    load_dataset(ds, run_ctx, task$name),
    error = function(e) {
      result$failed <<- TRUE
      result$error_message <<- paste0("load: ", e$message)
      NULL
    }
  )
  if (result$failed) {
    log_event(run_ctx, "error", "dataset_stage_failed", list(
      task = task$name,
      dataset = ds$id,
      stage = "load",
      elapsed_sec = as.numeric(Sys.time() - load_start),
      error_message = result$error_message
    ))
    return(result)
  }
  log_event(run_ctx, "debug", "dataset_stage_complete", list(
    task = task$name,
    dataset = ds$id,
    stage = "load",
    elapsed_sec = as.numeric(Sys.time() - load_start)
  ))
  
  prep_start <- Sys.time()
  dataset <- tryCatch(
    prepare_dataset_for_task(task$name, dataset, ds),
    error = function(e) {
      result$failed <<- TRUE
      result$error_message <<- paste0("prepare: ", e$message)
      NULL
    }
  )
  if (result$failed) {
    log_event(run_ctx, "error", "dataset_stage_failed", list(
      task = task$name,
      dataset = ds$id,
      stage = "prepare",
      elapsed_sec = as.numeric(Sys.time() - prep_start),
      error_message = result$error_message
    ))
    return(result)
  }
  log_event(run_ctx, "debug", "dataset_stage_complete", list(
    task = task$name,
    dataset = ds$id,
    stage = "prepare",
    elapsed_sec = as.numeric(Sys.time() - prep_start)
  ))
  
  split_start <- Sys.time()
  splits <- tryCatch(
    make_splits(task$name, dataset, task$split, ds$target, ds$id),
    error = function(e) {
      result$failed <<- TRUE
      result$error_message <<- paste0("split: ", e$message)
      NULL
    }
  )
  if (result$failed) {
    log_event(run_ctx, "error", "dataset_stage_failed", list(
      task = task$name,
      dataset = ds$id,
      stage = "split",
      elapsed_sec = as.numeric(Sys.time() - split_start),
      error_message = result$error_message
    ))
    return(result)
  }
  log_event(run_ctx, "debug", "dataset_stage_complete", list(
    task = task$name,
    dataset = ds$id,
    stage = "split",
    elapsed_sec = as.numeric(Sys.time() - split_start),
    n_splits = length(splits)
  ))
  
  model_names <- unique(c(
    vapply(task$model_pairs, function(p) p$single, character(1)),
    vapply(task$model_pairs, function(p) p$ensemble, character(1))
  ))
  
  # For multiclass classification, skip adaboost training (falls back to duplicate GBM)
  # Track alias mapping for pairwise comparison: adaboost -> gradient_boosting
  model_aliases <- list()
  if (task$name == "classification") {
    n_classes <- length(unique(dataset[[ds$target]]))
    if (n_classes > 2 && "adaboost" %in% model_names) {
      model_names <- setdiff(model_names, "adaboost")
      model_aliases[["adaboost"]] <- "gradient_boosting"
    }
  }
  
  eval_start <- Sys.time()
  # Parallelize splits for large split counts to reduce bottleneck
  if (length(splits) > 10 && parallel_workers > 1 && future_available) {
    n_split_workers <- min(4, max(1, parallel::detectCores() %/% 2))
    split_results <- future_map(splits, function(sp) {
      split_eval <- tryCatch({
        evaluate_models_on_split(task, dataset, ds, sp, model_names, run_ctx, timeout_sec, ds$id)
      }, error = function(e) {
        list(failed = TRUE, error_message = paste0("train_eval: ", e$message))
      })
      
      if (is.null(split_eval) || !is.null(split_eval$failed)) {
        return(list(model_rows = list(), pair_rows = list()))
      }
      
      pair_rows <- list()
      for (pair in task$model_pairs) {
        pair_result <- tryCatch({
          build_pair_rows_from_cache(task, ds, pair, sp, split_eval$model_cache, run_ctx, model_aliases)
        }, error = function(e) NULL)
        if (!is.null(pair_result)) {
          pair_rows <- c(pair_rows, pair_result)
        }
      }
      list(model_rows = split_eval$model_rows, pair_rows = pair_rows, worker_warnings = split_eval$worker_warnings)
    }, .options = furrr_options(seed = NULL))
    
    for (sr in split_results) {
      result$model_runs <- c(result$model_runs, sr$model_rows)
      result$pairwise_rows <- c(result$pairwise_rows, sr$pair_rows)
      result$warnings <- c(result$warnings, sr$worker_warnings)
    }
  } else {
    for (sp in splits) {
      split_eval <- tryCatch({
        evaluate_models_on_split(task, dataset, ds, sp, model_names, run_ctx, timeout_sec, ds$id)
      }, error = function(e) {
        result$failed <<- TRUE
        result$error_message <<- paste0("train_eval: ", e$message)
        return(NULL)
      })
      
      if (is.null(split_eval)) next

      result$model_runs <- c(result$model_runs, split_eval$model_rows)
      result$warnings <- c(result$warnings, split_eval$worker_warnings)
      
      for (pair in task$model_pairs) {
        pair_result <- tryCatch({
          build_pair_rows_from_cache(task, ds, pair, sp, split_eval$model_cache, run_ctx, model_aliases)
        }, error = function(e) {
          NULL
        })
        
        if (!is.null(pair_result)) {
          result$pairwise_rows <- c(result$pairwise_rows, pair_result)
        }
      }
    }
  }
  
  total_elapsed <- as.numeric(Sys.time() - dataset_start_time)
  eval_elapsed <- as.numeric(Sys.time() - eval_start)
  
  log_event(run_ctx, "info", "dataset_complete", list(
    task = task$name,
    dataset = ds$id,
    elapsed_sec = total_elapsed,
    load_sec = as.numeric(load_start - dataset_start_time),
    prepare_sec = as.numeric(prep_start - load_start),
    split_sec = as.numeric(split_start - prep_start),
    evaluate_sec = eval_elapsed,
    n_model_runs = length(result$model_runs),
    n_pairwise_rows = length(result$pairwise_rows),
    n_warnings = length(result$warnings),
    failed = result$failed
  ))
  
  result
}

evaluate_models_on_split <- function(task, dataset_df, ds_cfg, split, model_names, run_ctx, timeout_sec = 300, dataset_id = NULL) {
  train_df <- dataset_df[split$train_idx, , drop = FALSE]
  test_df <- dataset_df[split$test_idx, , drop = FALSE]

  prepped <- preprocess_split(task$name, train_df, test_df, ds_cfg)
  train_df <- prepped$train_df
  test_df <- prepped$test_df

  model_cache <- list()
  model_rows <- list()
  worker_warnings <- list()

  base_seed <- get_base_seed(dataset_id)

  for (model_name in model_names) {
    warning_ctx_base <- list(
      task = task$name,
      dataset = ds_cfg$id,
      fold = split$fold,
      repeat_id = split$repeat_id,
      model_name = model_name
    )

    model_seed <- make_split_seed(base_seed, split$repeat_id, split$fold) +
      sum(as.numeric(charToRaw(model_name)))
    RNGkind("Mersenne-Twister", normal.kind = "Inversion", sample.kind = "Rejection")
    set.seed(NULL)
    set.seed(model_seed)
    
    model_out <- NULL
    is_timeout <- FALSE
    error_message <- NULL
    
    model_family <- if (model_name %in% vapply(task$model_pairs, function(p) p$ensemble, character(1))) "ensemble" else "single"
    actual_model_used <- model_name
    if (model_name == "adaboost" && task$name == "classification") {
      n_classes <- length(unique(train_df[[ds_cfg$target]]))
      if (n_classes > 2) {
        actual_model_used <- "gradient_boosting"
      }
    }
    
    train_time <- tryCatch({
      system.time({
        model_out <- withCallingHandlers(
          with_timeout(
            run_model(task$name, model_name, train_df, test_df, ds_cfg$target, ds_cfg),
            timeout = timeout_sec
          ),
          warning = function(w) {
            worker_warnings[[length(worker_warnings) + 1]] <<- c(warning_ctx_base, list(stage = "model_train_predict", message = conditionMessage(w)))
            invokeRestart("muffleWarning")
          }
        )
      })
    }, error = function(e) {
      error_message <<- e$message
      if (grepl("timed out", e$message, ignore.case = TRUE)) {
        is_timeout <<- TRUE
      }
      worker_warnings[[length(worker_warnings) + 1]] <<- c(warning_ctx_base, list(stage = "model_train_predict", message = sprintf("Model %s failed: %s", model_name, e$message)))
      NULL
    })
    
    if (is.null(model_out) || is.null(train_time)) {
      failure_status <- if (is_timeout) "timeout" else "error"
      model_cache[[model_name]] <- list(
        metrics = as.list(setNames(rep(NA_real_, length(task$metrics)), task$metrics)),
        train_time = NA_real_,
        train_rows = nrow(train_df),
        test_rows = nrow(test_df),
        status = failure_status,
        model_family = model_family,
        actual_model_used = actual_model_used
      )
      for (m in task$metrics) {
        run_id_model <- make_row_id("run", run_ctx$run_id, task$name, ds_cfg$id, model_name, split$fold, split$repeat_id, m)
        model_rows[[length(model_rows) + 1]] <- list(
          run_id = run_id_model,
          task_type = task$name,
          dataset_id = ds_cfg$id,
          dataset_source = ds_cfg$source,
          model_family = model_family,
          model_name = model_name,
          actual_model_used = actual_model_used,
          split_method = split$split_method,
          fold = split$fold,
          repeat_id = split$repeat_id,
          n_folds = split$n_folds,
          train_rows = nrow(train_df),
          test_rows = nrow(test_df),
          train_time_sec = NA_real_,
          predict_time_sec = NA_real_,
          metric_name = m,
          metric_value = NA_real_,
          timestamp_utc = format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ"),
          status = failure_status,
          error_message = if (!is.null(error_message)) error_message else NA_character_
        )
      }
      next
    }
    
    train_time <- train_time[["elapsed"]]
    
    model_metrics <- withCallingHandlers(
      calc_metrics(task$name, test_df[[ds_cfg$target]], model_out$pred, model_out$prob),
      warning = function(w) {
        worker_warnings[[length(worker_warnings) + 1]] <<- c(warning_ctx_base, list(stage = "metrics", message = conditionMessage(w)))
        invokeRestart("muffleWarning")
      }
    )
    
    model_cache[[model_name]] <- list(
      metrics = model_metrics,
      train_time = train_time,
      train_rows = nrow(train_df),
      test_rows = nrow(test_df),
      status = "ok",
      model_family = model_family,
      actual_model_used = actual_model_used
    )
    
    metric_names <- names(model_metrics)
    metric_names <- metric_names[metric_names %in% task$metrics]
    
    for (m in metric_names) {
      run_id_model <- make_row_id("run", run_ctx$run_id, task$name, ds_cfg$id, model_name, split$fold, split$repeat_id, m)
      model_rows[[length(model_rows) + 1]] <- list(
        run_id = run_id_model,
        task_type = task$name,
        dataset_id = ds_cfg$id,
        dataset_source = ds_cfg$source,
        model_family = model_family,
        model_name = model_name,
        actual_model_used = actual_model_used,
        split_method = split$split_method,
        fold = split$fold,
        repeat_id = split$repeat_id,
        n_folds = split$n_folds,
        train_rows = nrow(train_df),
        test_rows = nrow(test_df),
        train_time_sec = train_time,
        predict_time_sec = NA_real_,
        metric_name = m,
        metric_value = model_metrics[[m]],
        timestamp_utc = format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ"),
        status = "ok",
        error_message = NA_character_
      )
    }
  }

  list(model_cache = model_cache, model_rows = model_rows, worker_warnings = worker_warnings)
}
