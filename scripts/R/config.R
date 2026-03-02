parse_args <- function(args) {
  out <- list(output_dir = "outputs", task_filter = NULL)
  if (length(args) == 0) return(out)

  i <- 1
  while (i <= length(args)) {
    key <- args[[i]]
    val <- if (i < length(args)) args[[i + 1]] else NULL
    if (key == "--output-dir") {
      out$output_dir <- val
      i <- i + 2
    } else if (key == "--task") {
      out$task_filter <- val
      i <- i + 2
    } else {
      i <- i + 1
    }
  }
  out
}

get_config <- function() {
  list(
    stop_on_first_fail = TRUE,
    tasks = list(
      list(
        name = "classification",
        split = list(method = "repeated_kfold", folds = 10, repeats = 5),
        metrics = c("accuracy", "precision", "recall", "f1", "roc_auc", "logloss"),
        datasets = list(
          list(id = "heart_disease", source = "uci", path = "data/classification/heart_disease.csv", url = "https://archive.ics.uci.edu/static/public/45/data.csv", target = "num"),
          list(id = "breast_cancer", source = "uci", path = "data/classification/breast_cancer.csv", url = "https://archive.ics.uci.edu/static/public/17/data.csv", target = "Diagnosis")
        ),
        model_pairs = list(
          list(single = "logistic_regression", ensemble = "gradient_boosting"),
          list(single = "decision_tree", ensemble = "adaboost"),
          list(single = "naive_bayes", ensemble = "gradient_boosting")
        )
      ),
      list(
        name = "regression",
        split = list(method = "repeated_kfold", folds = 10, repeats = 5),
        metrics = c("rmse", "mae", "r2", "mape"),
        datasets = list(
          list(id = "insurance", source = "kaggle", path = "data/regression/insurance.csv", url = "https://raw.githubusercontent.com/stedy/Machine-Learning-with-R-datasets/master/insurance.csv", target = "charges"),
          list(id = "housing_prices", source = "kaggle", path = "data/regression/housing_prices.csv", url = "", target = "price")
        ),
        model_pairs = list(
          list(single = "linear_regression", ensemble = "gradient_boosting_regressor"),
          list(single = "decision_tree_regressor", ensemble = "gradient_boosting_regressor"),
          list(single = "svr", ensemble = "gradient_boosting_regressor")
        )
      ),
      list(
        name = "timeseries",
        split = list(method = "rolling_origin", splits = 10),
        metrics = c("rmse", "mae", "mape", "smape"),
        datasets = list(
          list(id = "melbourne_temp", source = "other", path = "data/timeseries/melbourne_temp.csv", url = "", target = "Temp", time_col = "Date"),
          list(id = "electric_production", source = "other", path = "data/timeseries/electric_production.csv", url = "", target = "Value", time_col = "DATE")
        ),
        model_pairs = list(
          list(single = "arima", ensemble = "gbm_lag"),
          list(single = "exp_smoothing", ensemble = "gbm_lag")
        )
      )
    )
  )
}
