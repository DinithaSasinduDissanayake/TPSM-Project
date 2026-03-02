make_row_id <- function(prefix, ...) {
  paste(c(prefix, ...), collapse = "::")
}

prepare_dataset_for_task <- function(task_name, df, ds_cfg) {
  if (task_name == "timeseries" && !is.null(ds_cfg$time_col)) {
    df <- parse_time_column(df, ds_cfg$time_col)
  }
  
  if (task_name == "classification") {
    y <- df[[ds_cfg$target]]
    y_unique <- unique(y[!is.na(y)])
    n_classes <- length(y_unique)
    
    is_binary_forced <- !is.null(ds_cfg$force_binary) && ds_cfg$force_binary
    
    if (is_binary_forced && n_classes > 2) {
      if (!is.null(ds_cfg$binary_positive_vals)) {
        y_chr <- as.character(y)
        y_bin <- ifelse(tolower(y_chr) %in% tolower(ds_cfg$binary_positive_vals), 1, 0)
        df[[ds_cfg$target]] <- factor(y_bin, levels = c(0, 1), labels = c("0", "1"))
      } else if (!is.null(ds_cfg$binary_threshold)) {
        y_num <- as.numeric(y)
        y_bin <- ifelse(y_num > ds_cfg$binary_threshold, 1, 0)
        df[[ds_cfg$target]] <- factor(y_bin, levels = c(0, 1), labels = c("0", "1"))
      } else {
        df[[ds_cfg$target]] <- as.factor(y)
      }
    } else if (n_classes == 2) {
      y_chr <- tolower(as.character(y))
      y_bin <- ifelse(y_chr %in% c("m", "malignant", "yes", "true", "1", "positive", "good", "1"), 1, 0)
      df[[ds_cfg$target]] <- factor(y_bin, levels = c(0, 1), labels = c("0", "1"))
    } else {
      df[[ds_cfg$target]] <- as.factor(y)
    }
  }
  df
}

infer_id_columns <- function(df, target_col) {
  out <- character(0)
  for (col in names(df)) {
    if (col == target_col) next
    if (tolower(col) %in% c("id", "identifier", "uid")) {
      out <- c(out, col)
      next
    }
    if (length(unique(df[[col]])) == nrow(df)) {
      out <- c(out, col)
    }
  }
  unique(out)
}

fit_imputer <- function(train_df) {
  num_medians <- list()
  cat_modes <- list()
  for (col in names(train_df)) {
    if (is.numeric(train_df[[col]]) || is.integer(train_df[[col]])) {
      num_medians[[col]] <- stats::median(train_df[[col]], na.rm = TRUE)
    } else {
      vals <- train_df[[col]][!is.na(train_df[[col]])]
      if (length(vals) > 0) {
        cat_modes[[col]] <- names(sort(table(vals), decreasing = TRUE))[1]
      }
    }
  }
  list(num_medians = num_medians, cat_modes = cat_modes)
}

apply_imputer <- function(df, imputer) {
  for (col in names(df)) {
    if (is.numeric(df[[col]]) || is.integer(df[[col]])) {
      med <- imputer$num_medians[[col]]
      if (!is.null(med)) {
        df[[col]][is.na(df[[col]])] <- med
        df[[col]][is.nan(df[[col]])] <- med
      }
    } else {
      mode_val <- imputer$cat_modes[[col]]
      if (!is.null(mode_val)) {
        df[[col]][is.na(df[[col]])] <- mode_val
      }
    }
  }
  df
}

fit_categorical_encoder <- function(train_df, target_col) {
  levels_map <- list()
  for (col in names(train_df)) {
    if (col == target_col) next
    if (!is.numeric(train_df[[col]]) && !is.integer(train_df[[col]])) {
      levels_map[[col]] <- unique(as.character(train_df[[col]]))
    }
  }
  list(levels_map = levels_map)
}

apply_categorical_encoder <- function(df, encoder, imputer, target_col) {
  for (col in names(encoder$levels_map)) {
    if (col == target_col || !col %in% names(df)) next
    lvls <- encoder$levels_map[[col]]
    df[[col]] <- as.numeric(factor(df[[col]], levels = lvls))
    if (is.null(imputer$num_medians[[col]])) {
      med <- stats::median(df[[col]], na.rm = TRUE)
      df[[col]][is.na(df[[col]])] <- med
      df[[col]][is.nan(df[[col]])] <- med
    }
  }
  df
}

fit_scaler <- function(train_df, target_col) {
  means <- list()
  sds <- list()
  for (col in names(train_df)) {
    if (col == target_col) next
    if (is.numeric(train_df[[col]]) || is.integer(train_df[[col]])) {
      means[[col]] <- mean(train_df[[col]], na.rm = TRUE)
      sds_col <- sd(train_df[[col]], na.rm = TRUE)
      sds[[col]] <- ifelse(sds_col == 0, 1, sds_col)
    }
  }
  list(means = means, sds = sds)
}

apply_scaler <- function(df, scaler, target_col) {
  for (col in names(scaler$means)) {
    if (!col %in% names(df)) next
    df[[col]] <- (df[[col]] - scaler$means[[col]]) / scaler$sds[[col]]
  }
  df
}

preprocess_split <- function(task_name, train_df, test_df, ds_cfg) {
  drop_cols <- character(0)
  if (!is.null(ds_cfg$exclude_cols)) {
    drop_cols <- c(drop_cols, ds_cfg$exclude_cols)
  }
  drop_cols <- c(drop_cols, infer_id_columns(train_df, ds_cfg$target))
  if (!is.null(ds_cfg$time_col)) {
    drop_cols <- c(drop_cols, ds_cfg$time_col)
  }
  drop_cols <- unique(drop_cols)

  if (length(drop_cols) > 0) {
    train_df <- train_df[, setdiff(names(train_df), drop_cols), drop = FALSE]
    test_df <- test_df[, setdiff(names(test_df), drop_cols), drop = FALSE]
  }

  imputer <- fit_imputer(train_df)
  train_df <- apply_imputer(train_df, imputer)
  test_df <- apply_imputer(test_df, imputer)

  if (task_name == "classification") {
    encoder <- fit_categorical_encoder(train_df, ds_cfg$target)
    train_df <- apply_categorical_encoder(train_df, encoder, imputer, ds_cfg$target)
    test_df <- apply_categorical_encoder(test_df, encoder, imputer, ds_cfg$target)
  }
  
  if (task_name == "regression") {
    encoder <- fit_categorical_encoder(train_df, ds_cfg$target)
    train_df <- apply_categorical_encoder(train_df, encoder, imputer, ds_cfg$target)
    test_df <- apply_categorical_encoder(test_df, encoder, imputer, ds_cfg$target)
    
    scaler <- fit_scaler(train_df, ds_cfg$target)
    train_df <- apply_scaler(train_df, scaler, ds_cfg$target)
    test_df <- apply_scaler(test_df, scaler, ds_cfg$target)
  }
  
  if (task_name == "timeseries") {
    encoder <- fit_categorical_encoder(train_df, ds_cfg$target)
    train_df <- apply_categorical_encoder(train_df, encoder, imputer, ds_cfg$target)
    test_df <- apply_categorical_encoder(test_df, encoder, imputer, ds_cfg$target)
  }

  list(train_df = train_df, test_df = test_df)
}

evaluate_models_on_split <- function(task, dataset_df, ds_cfg, split, model_names, run_ctx) {
  train_df <- dataset_df[split$train_idx, , drop = FALSE]
  test_df <- dataset_df[split$test_idx, , drop = FALSE]

  prepped <- preprocess_split(task$name, train_df, test_df, ds_cfg)
  train_df <- prepped$train_df
  test_df <- prepped$test_df

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
    
    exog_train <- NULL
    exog_test <- NULL
    if (!is.null(ds_cfg$exog_cols)) {
      exog_cols <- ds_cfg$exog_cols
      valid_exog <- intersect(exog_cols, names(train_df))
      if (length(valid_exog) > 0) {
        exog_train <- train_df[, valid_exog, drop = FALSE]
        exog_test <- test_df[, valid_exog, drop = FALSE]
      }
    }
    
    pred <- train_predict_timeseries(model_name, y_train, y_test, lag = 12, exog_train = exog_train, exog_test = exog_test)
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
