make_row_id <- function(prefix, ...) {
  paste(c(prefix, ...), collapse = "::")
}

prepare_dataset_for_task <- function(task_name, df, ds_cfg) {
  if (task_name == "timeseries" && !is.null(ds_cfg$time_col)) {
    time_col <- ds_cfg$time_col
    if (time_col %in% names(df)) {
      parsed <- tryCatch({
        as.POSIXct(df[[time_col]], tz = "UTC")
      }, error = function(e) {
        tryCatch({
          as.Date(df[[time_col]])
        }, error = function(e2) {
          NULL
        })
      })
      if (!is.null(parsed) && !all(is.na(parsed))) {
        df <- df[order(parsed), ]
      }
    }
    df <- parse_time_column(df, ds_cfg$time_col)
  }
  df
}

prepare_target_for_split <- function(task_name, train_df, test_df, target_col, ds_cfg) {
  if (task_name != "classification") {
    return(list(train_df = train_df, test_df = test_df))
  }

  y_train <- train_df[[target_col]]
  y_test <- test_df[[target_col]]
  y_train_unique <- unique(y_train[!is.na(y_train)])
  n_classes <- length(y_train_unique)

  is_binary_forced <- !is.null(ds_cfg$force_binary) && ds_cfg$force_binary

  if (is_binary_forced && n_classes > 2) {
    if (!is.null(ds_cfg$binary_positive_vals)) {
      y_train_chr <- as.character(y_train)
      y_test_chr <- as.character(y_test)
      y_train_bin <- ifelse(tolower(y_train_chr) %in% tolower(ds_cfg$binary_positive_vals), 1, 0)
      y_test_bin <- ifelse(tolower(y_test_chr) %in% tolower(ds_cfg$binary_positive_vals), 1, 0)
      train_df[[target_col]] <- factor(y_train_bin, levels = c(0, 1), labels = c("0", "1"))
      test_df[[target_col]] <- factor(y_test_bin, levels = c(0, 1), labels = c("0", "1"))
    } else if (!is.null(ds_cfg$binary_threshold)) {
      y_train_num <- as.numeric(y_train)
      y_test_num <- as.numeric(y_test)
      y_train_bin <- ifelse(y_train_num > ds_cfg$binary_threshold, 1, 0)
      y_test_bin <- ifelse(y_test_num > ds_cfg$binary_threshold, 1, 0)
      train_df[[target_col]] <- factor(y_train_bin, levels = c(0, 1), labels = c("0", "1"))
      test_df[[target_col]] <- factor(y_test_bin, levels = c(0, 1), labels = c("0", "1"))
    } else {
      stop(sprintf("force_binary=TRUE with %d classes requires binary_positive_vals or binary_threshold in config for dataset '%s'", n_classes, ds_cfg$id))
    }
  } else if (n_classes == 2) {
    y_train_chr <- as.character(y_train)
    y_test_chr <- as.character(y_test)
    unique_vals <- sort(unique(y_train_chr))
    if (length(unique_vals) != 2) {
      stop(sprintf("Expected 2 classes in training data, got %d", length(unique_vals)))
    }
    if (!is.null(ds_cfg$positive_class)) {
      positive_val <- ds_cfg$positive_class
    } else {
      positive_val <- unique_vals[2]
      warning(sprintf(
        "No positive class specified for '%s', using '%s' (alphabetically second). Consider setting positive_class in config.",
        ds_cfg$id, positive_val
      ))
    }
    y_train_bin <- ifelse(y_train_chr == positive_val, 1, 0)
    y_test_bin <- ifelse(y_test_chr == positive_val, 1, 0)
    train_df[[target_col]] <- factor(y_train_bin, levels = c(0, 1), labels = c("0", "1"))
    test_df[[target_col]] <- factor(y_test_bin, levels = c(0, 1), labels = c("0", "1"))
  } else {
    train_df[[target_col]] <- as.factor(y_train)
    test_df[[target_col]] <- as.factor(y_test)
  }

  list(train_df = train_df, test_df = test_df)
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
      if (is.integer(df[[col]]) || is.character(df[[col]]) || is.factor(df[[col]])) {
        out <- c(out, col)
      }
    }
  }
  unique(out)
}

fit_imputer <- function(train_df, target_col = NULL) {
  num_medians <- list()
  cat_modes <- list()
  for (col in names(train_df)) {
    if (!is.null(target_col) && col == target_col) next
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
        df[[col]][is.infinite(df[[col]])] <- med
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
  fallback_medians <- list()
  for (col in names(train_df)) {
    if (col == target_col) next
    if (!is.numeric(train_df[[col]]) && !is.integer(train_df[[col]])) {
      levels_map[[col]] <- unique(as.character(train_df[[col]]))
      enc_temp <- as.numeric(factor(train_df[[col]], levels = levels_map[[col]]))
      fallback_medians[[col]] <- stats::median(enc_temp, na.rm = TRUE)
    }
  }
  list(levels_map = levels_map, fallback_medians = fallback_medians)
}

apply_categorical_encoder <- function(df, encoder, imputer, target_col) {
  for (col in names(encoder$levels_map)) {
    if (col == target_col || !col %in% names(df)) next
    lvls <- encoder$levels_map[[col]]
    df[[col]] <- as.numeric(factor(df[[col]], levels = lvls))
    if (is.null(imputer$num_medians[[col]])) {
      med <- encoder$fallback_medians[[col]]
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

  target_prepped <- prepare_target_for_split(task_name, train_df, test_df, ds_cfg$target, ds_cfg)
  train_df <- target_prepped$train_df
  test_df <- target_prepped$test_df

  imputer <- fit_imputer(train_df, ds_cfg$target)
  train_df <- apply_imputer(train_df, imputer)
  test_df <- apply_imputer(test_df, imputer)

  train_df <- train_df[!is.na(train_df[[ds_cfg$target]]), , drop = FALSE]
  test_df <- test_df[!is.na(test_df[[ds_cfg$target]]), , drop = FALSE]

  encoder <- fit_categorical_encoder(train_df, ds_cfg$target)
  train_df <- apply_categorical_encoder(train_df, encoder, imputer, ds_cfg$target)
  test_df <- apply_categorical_encoder(test_df, encoder, imputer, ds_cfg$target)

  if (task_name %in% c("classification", "regression")) {
    scaler <- fit_scaler(train_df, ds_cfg$target)
    train_df <- apply_scaler(train_df, scaler, ds_cfg$target)
    test_df <- apply_scaler(test_df, scaler, ds_cfg$target)
  }

  feature_cols <- setdiff(names(train_df), ds_cfg$target)
  zero_var <- vapply(feature_cols, function(col) {
    length(unique(train_df[[col]][!is.na(train_df[[col]])])) <= 1
  }, logical(1))
  if (any(zero_var)) {
    drop <- names(which(zero_var))
    train_df <- train_df[, setdiff(names(train_df), drop), drop = FALSE]
    test_df <- test_df[, setdiff(names(test_df), drop), drop = FALSE]
  }

  list(train_df = train_df, test_df = test_df)
}

build_pair_rows_from_cache <- function(task, ds_cfg, pair, split, model_cache, run_ctx) {
  metric_single <- model_cache[[pair$single]]$metrics
  metric_ensemble <- model_cache[[pair$ensemble]]$metrics
  
  metric_names <- intersect(names(metric_single), names(metric_ensemble))
  metric_names <- metric_names[metric_names %in% task$metrics]
  
  actual_single <- model_cache[[pair$single]]$actual_model_used
  actual_ensemble <- model_cache[[pair$ensemble]]$actual_model_used
  
  single_model_name_to_use <- if (!is.null(actual_single)) actual_single else pair$single
  ensemble_model_name_to_use <- if (!is.null(actual_ensemble)) actual_ensemble else pair$ensemble
  
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
      single_model_name = single_model_name_to_use,
      ensemble_model_name = ensemble_model_name_to_use,
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
