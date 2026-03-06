validate_config <- function(cfg) {
  errors <- character(0)

  for (task in cfg$tasks) {
    if (length(task$datasets) == 0) {
      errors <- c(errors, sprintf("Task '%s' has no datasets", task$name))
    }
    if (length(task$model_pairs) == 0) {
      errors <- c(errors, sprintf("Task '%s' has no model pairs", task$name))
    }
    for (ds in task$datasets) {
      if (is.null(ds$target)) {
        errors <- c(errors, sprintf("Dataset '%s' missing target", ds$id))
      }
    }
    known_models <- list(
      classification = c("logistic_regression", "decision_tree",
                         "naive_bayes", "gradient_boosting", "random_forest", "adaboost"),
      regression = c("linear_regression", "decision_tree_regressor",
                     "svr", "gradient_boosting_regressor"),
      timeseries = c("arima", "exp_smoothing", "gbm_lag")
    )
    for (pair in task$model_pairs) {
      for (m in c(pair$single, pair$ensemble)) {
        if (!m %in% known_models[[task$name]]) {
          errors <- c(errors, sprintf(
            "Unknown model '%s' in task '%s'", m, task$name
          ))
        }
      }
    }
  }

  if (length(errors) > 0) {
    stop(paste("Config validation failed:\n",
               paste("-", errors, collapse = "\n")))
  }
  invisible(TRUE)
}

validate_dataset <- function(df, ds_cfg, task_name) {
  issues <- character(0)

  if (nrow(df) < 50) {
    issues <- c(issues, sprintf("Only %d rows - too few for reliable CV", nrow(df)))
  }

  target_na_pct <- mean(is.na(df[[ds_cfg$target]])) * 100
  if (target_na_pct > 20) {
    issues <- c(issues, sprintf("Target has %.1f%% missing values", target_na_pct))
  }

  if (task_name == "classification") {
    tab <- table(df[[ds_cfg$target]])
    min_class_pct <- min(tab) / sum(tab) * 100
    if (min_class_pct < 5) {
      issues <- c(issues, sprintf(
        "Severe class imbalance: minority class = %.1f%%", min_class_pct
      ))
    }
  }

  for (col in names(df)) {
    if (length(unique(df[[col]][!is.na(df[[col]])])) <= 1) {
      issues <- c(issues, sprintf("Column '%s' is constant", col))
    }
  }

  list(valid = length(issues) == 0, issues = issues)
}
