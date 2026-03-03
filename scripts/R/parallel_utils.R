make_split_seed <- function(base_seed, repeat_id, fold) {
  base_seed + (repeat_id - 1) * 1000 + fold
}

with_timeout <- function(expr, timeout = 300, on_timeout = "error") {
  if (!requireNamespace("R.utils", quietly = TRUE)) {
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

  dataset <- tryCatch(
    load_dataset(ds, run_ctx, task$name),
    error = function(e) {
      result$failed <<- TRUE
      result$error_message <<- paste0("load: ", e$message)
      NULL
    }
  )
  if (result$failed) return(result)
  
  dataset <- tryCatch(
    prepare_dataset_for_task(task$name, dataset, ds),
    error = function(e) {
      result$failed <<- TRUE
      result$error_message <<- paste0("prepare: ", e$message)
      NULL
    }
  )
  if (result$failed) return(result)
  
  splits <- tryCatch(
    make_splits(task$name, dataset, task$split, ds$target, ds$id),
    error = function(e) {
      result$failed <<- TRUE
      result$error_message <<- paste0("split: ", e$message)
      NULL
    }
  )
  if (result$failed) return(result)
  
  model_names <- unique(c(
    vapply(task$model_pairs, function(p) p$single, character(1)),
    vapply(task$model_pairs, function(p) p$ensemble, character(1))
  ))
  
  for (sp in splits) {
    split_eval <- tryCatch({
      evaluate_models_on_split(task, dataset, ds, sp, model_names, run_ctx, timeout_sec, ds$id)
    }, error = function(e) {
      result$failed <<- TRUE
      result$error_message <<- paste0("train_eval: ", e$message)
      return(NULL)
    })
    
    if (is.null(split_eval)) break

    result$model_runs <- c(result$model_runs, split_eval$model_rows)
    result$warnings <- c(result$warnings, split_eval$worker_warnings)
    
    for (pair in task$model_pairs) {
      pair_result <- tryCatch({
        build_pair_rows_from_cache(task, ds, pair, sp, split_eval$model_cache, run_ctx)
      }, error = function(e) {
        NULL
      })
      
      if (!is.null(pair_result)) {
        result$pairwise_rows <- c(result$pairwise_rows, pair_result)
      }
    }
  }
  
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

  base_seed <- 42
  if (!is.null(dataset_id)) {
    seed_hash <- sum(as.numeric(charToRaw(dataset_id))) %% 100000
    base_seed <- base_seed + seed_hash
  }

  for (model_name in model_names) {
    warning_ctx_base <- list(
      task = task$name,
      dataset = ds_cfg$id,
      fold = split$fold,
      repeat_id = split$repeat_id,
      model_name = model_name
    )

    model_seed <- make_split_seed(base_seed, split$repeat_id, split$fold)
    set.seed(model_seed)
    
    model_out <- NULL
    train_time <- tryCatch({
      system.time({
        model_out <- withCallingHandlers(
          with_timeout(
            run_model(task$name, model_name, train_df, test_df, ds_cfg$target, ds_cfg),
            timeout = timeout_sec
          ),
          warning = function(w) {
            worker_warnings[[length(worker_warnings) + 1]] <- c(warning_ctx_base, list(stage = "model_train_predict", message = conditionMessage(w)))
            invokeRestart("muffleWarning")
          }
        )
      })
    }, error = function(e) {
      worker_warnings[[length(worker_warnings) + 1]] <- c(warning_ctx_base, list(stage = "model_train_predict", message = sprintf("Model %s failed: %s", model_name, e$message)))
      NULL
    })
    
    if (is.null(model_out) || is.null(train_time)) {
      model_cache[[model_name]] <- list(
        metrics = as.list(setNames(rep(NA_real_, length(task$metrics)), task$metrics)),
        train_time = NA_real_,
        train_rows = nrow(train_df),
        test_rows = nrow(test_df),
        status = "timeout"
      )
      model_family <- if (model_name %in% vapply(task$model_pairs, function(p) p$ensemble, character(1))) "ensemble" else "single"
      for (m in task$metrics) {
        run_id_model <- make_row_id("run", run_ctx$run_id, task$name, ds_cfg$id, model_name, split$fold, split$repeat_id, m)
        model_rows[[length(model_rows) + 1]] <- list(
          run_id = run_id_model,
          task_type = task$name,
          dataset_id = ds_cfg$id,
          dataset_source = ds_cfg$source,
          model_family = model_family,
          model_name = model_name,
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
          status = "timeout",
          error_message = NA_character_
        )
      }
      next
    }
    
    train_time <- train_time[["elapsed"]]
    
    model_metrics <- withCallingHandlers(
      calc_metrics(task$name, test_df[[ds_cfg$target]], model_out$pred, model_out$prob),
      warning = function(w) {
        worker_warnings[[length(worker_warnings) + 1]] <- c(warning_ctx_base, list(stage = "metrics", message = conditionMessage(w)))
        invokeRestart("muffleWarning")
      }
    )
    
    model_cache[[model_name]] <- list(
      metrics = model_metrics,
      train_time = train_time,
      train_rows = nrow(train_df),
      test_rows = nrow(test_df),
      status = "ok"
    )
    
    metric_names <- names(model_metrics)
    metric_names <- metric_names[metric_names %in% task$metrics]
    
    model_family <- if (model_name %in% vapply(task$model_pairs, function(p) p$ensemble, character(1))) "ensemble" else "single"
    
    for (m in metric_names) {
      run_id_model <- make_row_id("run", run_ctx$run_id, task$name, ds_cfg$id, model_name, split$fold, split$repeat_id, m)
      model_rows[[length(model_rows) + 1]] <- list(
        run_id = run_id_model,
        task_type = task$name,
        dataset_id = ds_cfg$id,
        dataset_source = ds_cfg$source,
        model_family = model_family,
        model_name = model_name,
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
