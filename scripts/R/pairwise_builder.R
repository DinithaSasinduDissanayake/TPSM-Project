make_row_id <- function(prefix, ...) {
  paste(c(prefix, ...), collapse = "::")
}

prepare_dataset_for_task <- function(task_name, df, ds_cfg) {
  # Basic missing value handling
  for (col in names(df)) {
    if (all(is.na(df[[col]]))) next
    if (is.numeric(df[[col]]) || is.integer(df[[col]])) {
      med <- stats::median(df[[col]], na.rm = TRUE)
      df[[col]][is.na(df[[col]])] <- med
      df[[col]][is.nan(df[[col]])] <- med
    } else {
      vals <- df[[col]][!is.na(df[[col]])]
      if (length(vals) > 0) {
        mode_val <- names(sort(table(vals), decreasing = TRUE))[1]
        df[[col]][is.na(df[[col]])] <- mode_val
      }
    }
  }

  # Encode categorical variables as numeric for regression/time series
  if (task_name %in% c("regression", "timeseries")) {
    for (col in names(df)) {
      if (!is.numeric(df[[col]]) && !is.integer(df[[col]])) {
        df[[col]] <- as.numeric(factor(df[[col]]))
      }
    }
  }

  if (task_name == "classification") {
    y <- df[[ds_cfg$target]]
    if (is.numeric(y) || is.integer(y)) {
      # Heart disease style: 0 = no disease, 1..4 = disease
      y_bin <- ifelse(y > 0, 1, 0)
    } else {
      y_chr <- tolower(as.character(y))
      y_bin <- ifelse(y_chr %in% c("m", "malignant", "yes", "true", "1", "positive"), 1, 0)
    }
    df[[ds_cfg$target]] <- factor(y_bin, levels = c(0, 1), labels = c("0", "1"))
  }
  df
}

evaluate_pair_on_split <- function(task, dataset_df, ds_cfg, pair, split, run_ctx) {
  train_df <- dataset_df[split$train_idx, , drop = FALSE]
  test_df <- dataset_df[split$test_idx, , drop = FALSE]

  warning_ctx_base <- list(
    task = task$name,
    dataset = ds_cfg$id,
    single = pair$single,
    ensemble = pair$ensemble,
    fold = split$fold,
    repeat_id = split$repeat_id
  )

  single_out <- list()
  ensemble_out <- list()
  single_time <- system.time({
    single_out <- withCallingHandlers(
      run_model(task$name, pair$single, train_df, test_df, ds_cfg$target, ds_cfg),
      warning = function(w) {
        log_warning(run_ctx, conditionMessage(w), c(warning_ctx_base, list(stage = "model_train_predict", model_name = pair$single)))
        invokeRestart("muffleWarning")
      }
    )
  })[["elapsed"]]
  ensemble_time <- system.time({
    ensemble_out <- withCallingHandlers(
      run_model(task$name, pair$ensemble, train_df, test_df, ds_cfg$target, ds_cfg),
      warning = function(w) {
        log_warning(run_ctx, conditionMessage(w), c(warning_ctx_base, list(stage = "model_train_predict", model_name = pair$ensemble)))
        invokeRestart("muffleWarning")
      }
    )
  })[["elapsed"]]

  metric_single <- withCallingHandlers(
    calc_metrics(task$name, test_df[[ds_cfg$target]], single_out$pred, single_out$prob),
    warning = function(w) {
      log_warning(run_ctx, conditionMessage(w), c(warning_ctx_base, list(stage = "metrics", model_name = pair$single)))
      invokeRestart("muffleWarning")
    }
  )
  metric_ensemble <- withCallingHandlers(
    calc_metrics(task$name, test_df[[ds_cfg$target]], ensemble_out$pred, ensemble_out$prob),
    warning = function(w) {
      log_warning(run_ctx, conditionMessage(w), c(warning_ctx_base, list(stage = "metrics", model_name = pair$ensemble)))
      invokeRestart("muffleWarning")
    }
  )

  metric_names <- intersect(names(metric_single), names(metric_ensemble))
  metric_names <- metric_names[metric_names %in% task$metrics]

  model_rows <- list()
  pair_rows <- list()

  for (m in metric_names) {
    run_id_single <- make_row_id("run", run_ctx$run_id, task$name, ds_cfg$id, pair$single, split$fold, split$repeat_id, m)
    run_id_ens <- make_row_id("run", run_ctx$run_id, task$name, ds_cfg$id, pair$ensemble, split$fold, split$repeat_id, m)

    model_rows[[length(model_rows) + 1]] <- list(
      run_id = run_id_single,
      task_type = task$name,
      dataset_id = ds_cfg$id,
      dataset_source = ds_cfg$source,
      model_family = "single",
      model_name = pair$single,
      split_method = split$split_method,
      fold = split$fold,
      repeat_id = split$repeat_id,
      n_folds = split$n_folds,
      train_rows = nrow(train_df),
      test_rows = nrow(test_df),
      train_time_sec = single_time,
      predict_time_sec = NA_real_,
      metric_name = m,
      metric_value = metric_single[[m]],
      timestamp_utc = format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ"),
      status = "ok",
      error_message = NA_character_
    )

    model_rows[[length(model_rows) + 1]] <- list(
      run_id = run_id_ens,
      task_type = task$name,
      dataset_id = ds_cfg$id,
      dataset_source = ds_cfg$source,
      model_family = "ensemble",
      model_name = pair$ensemble,
      split_method = split$split_method,
      fold = split$fold,
      repeat_id = split$repeat_id,
      n_folds = split$n_folds,
      train_rows = nrow(train_df),
      test_rows = nrow(test_df),
      train_time_sec = ensemble_time,
      predict_time_sec = NA_real_,
      metric_name = m,
      metric_value = metric_ensemble[[m]],
      timestamp_utc = format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ"),
      status = "ok",
      error_message = NA_character_
    )

    higher <- is_higher_better(m)
    d <- if (higher) metric_ensemble[[m]] - metric_single[[m]] else metric_single[[m]] - metric_ensemble[[m]]
    def <- if (higher) paste0("ensemble_minus_single_", m) else paste0("single_minus_ensemble_", m)

    pair_rows[[length(pair_rows) + 1]] <- list(
      comparison_id = make_row_id("cmp", run_ctx$run_id, task$name, ds_cfg$id, pair$single, pair$ensemble, split$fold, split$repeat_id, m),
      run_id = run_ctx$run_id,
      task_type = task$name,
      dataset_id = ds_cfg$id,
      split_method = split$split_method,
      fold = split$fold,
      repeat_id = split$repeat_id,
      metric_name = m,
      single_model_name = pair$single,
      ensemble_model_name = pair$ensemble,
      single_metric_value = metric_single[[m]],
      ensemble_metric_value = metric_ensemble[[m]],
      difference_definition = def,
      difference_value = d,
      ensemble_better = isTRUE(d > 0),
      valid_pair = !is.na(d),
      notes = NA_character_
    )
  }

  list(model_rows = model_rows, pair_rows = pair_rows)
}

evaluate_models_on_split <- function(task, dataset_df, ds_cfg, split, model_names, run_ctx) {
  train_df <- dataset_df[split$train_idx, , drop = FALSE]
  test_df <- dataset_df[split$test_idx, , drop = FALSE]

  model_cache <- list()
  model_rows <- list()

  for (model_name in model_names) {
    warning_ctx_base <- list(
      task = task$name,
      dataset = ds_cfg$id,
      fold = split$fold,
      repeat_id = split$repeat_id,
      model_name = model_name
    )

    model_out <- list()
    train_time <- system.time({
      model_out <- withCallingHandlers(
        run_model(task$name, model_name, train_df, test_df, ds_cfg$target, ds_cfg),
        warning = function(w) {
          log_warning(run_ctx, conditionMessage(w), c(warning_ctx_base, list(stage = "model_train_predict")))
          invokeRestart("muffleWarning")
        }
      )
    })[["elapsed"]]

    model_metrics <- withCallingHandlers(
      calc_metrics(task$name, test_df[[ds_cfg$target]], model_out$pred, model_out$prob),
      warning = function(w) {
        log_warning(run_ctx, conditionMessage(w), c(warning_ctx_base, list(stage = "metrics")))
        invokeRestart("muffleWarning")
      }
    )

    model_cache[[model_name]] <- list(
      metrics = model_metrics,
      train_time = train_time,
      train_rows = nrow(train_df),
      test_rows = nrow(test_df)
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

  list(model_cache = model_cache, model_rows = model_rows)
}

build_pair_rows_from_cache <- function(task, ds_cfg, pair, split, model_cache, run_ctx) {
  metric_single <- model_cache[[pair$single]]$metrics
  metric_ensemble <- model_cache[[pair$ensemble]]$metrics

  metric_names <- intersect(names(metric_single), names(metric_ensemble))
  metric_names <- metric_names[metric_names %in% task$metrics]

  pair_rows <- list()
  for (m in metric_names) {
    higher <- is_higher_better(m)
    d <- if (higher) metric_ensemble[[m]] - metric_single[[m]] else metric_single[[m]] - metric_ensemble[[m]]
    def <- if (higher) paste0("ensemble_minus_single_", m) else paste0("single_minus_ensemble_", m)

    pair_rows[[length(pair_rows) + 1]] <- list(
      comparison_id = make_row_id("cmp", run_ctx$run_id, task$name, ds_cfg$id, pair$single, pair$ensemble, split$fold, split$repeat_id, m),
      run_id = run_ctx$run_id,
      task_type = task$name,
      dataset_id = ds_cfg$id,
      split_method = split$split_method,
      fold = split$fold,
      repeat_id = split$repeat_id,
      metric_name = m,
      single_model_name = pair$single,
      ensemble_model_name = pair$ensemble,
      single_metric_value = metric_single[[m]],
      ensemble_metric_value = metric_ensemble[[m]],
      difference_definition = def,
      difference_value = d,
      ensemble_better = isTRUE(d > 0),
      valid_pair = !is.na(d),
      notes = NA_character_
    )
  }

  pair_rows
}

run_model <- function(task_name, model_name, train_df, test_df, target_col, ds_cfg) {
  if (task_name == "classification") {
    return(train_predict_classification(model_name, train_df, test_df, target_col))
  }
  if (task_name == "regression") {
    pred <- train_predict_regression(model_name, train_df, test_df, target_col)
    return(list(pred = pred, prob = NULL))
  }
  if (task_name == "timeseries") {
    y_train <- train_df[[target_col]]
    y_test <- test_df[[target_col]]
    pred <- train_predict_timeseries(model_name, y_train, y_test, lag = 12)
    return(list(pred = pred, prob = NULL))
  }
  stop(sprintf("Unsupported task: %s", task_name))
}

calc_metrics <- function(task_name, y_true, y_pred, y_prob = NULL) {
  if (task_name == "classification") return(classification_metrics(y_true, y_pred, y_prob))
  if (task_name == "regression") return(regression_metrics(as.numeric(y_true), as.numeric(y_pred)))
  if (task_name == "timeseries") return(timeseries_metrics(as.numeric(y_true), as.numeric(y_pred)))
  stop(sprintf("Unsupported task: %s", task_name))
}
