make_lag_matrix <- function(y, max_lag = 12) {
  n <- length(y)
  out <- data.frame(target = y)
  for (l in seq_len(max_lag)) {
    out[[paste0("lag_", l)]] <- dplyr::lag(y, l)
  }
  stats::na.omit(out)
}

train_predict_timeseries <- function(model_name, y_train, y_test, lag = 12) {
  if (model_name == "arima") {
    fit <- stats::arima(y_train, order = c(1, 1, 1))
    fc <- stats::predict(fit, n.ahead = length(y_test))$pred
    return(as.numeric(fc))
  }

  if (model_name == "exp_smoothing") {
    fit <- stats::HoltWinters(stats::ts(y_train), beta = FALSE, gamma = FALSE)
    fc <- stats::predict(fit, n.ahead = length(y_test))
    return(as.numeric(fc))
  }

  full <- c(y_train, y_test)
  lag_df <- make_lag_matrix(full, max_lag = lag)
  split_point <- length(y_train) - lag
  train_df <- lag_df[seq_len(split_point), , drop = FALSE]
  test_df <- lag_df[(split_point + 1):nrow(lag_df), , drop = FALSE]

  x_train <- as.matrix(train_df[, setdiff(names(train_df), "target"), drop = FALSE])
  y_train_lag <- train_df$target
  x_test <- as.matrix(test_df[, setdiff(names(test_df), "target"), drop = FALSE])

  if (model_name == "gbm_lag") {
    if (!requireNamespace("gbm", quietly = TRUE)) stop("Package 'gbm' required")
    train_lag_df <- data.frame(target = y_train_lag, x_train)
    test_lag_df <- data.frame(x_test)
    names(train_lag_df) <- c("target", paste0("x", seq_len(ncol(x_train))))
    names(test_lag_df) <- paste0("x", seq_len(ncol(x_test)))
    fit <- gbm::gbm(target ~ ., data = train_lag_df, distribution = "gaussian", n.trees = 100, interaction.depth = 3, shrinkage = 0.05, n.minobsinnode = 10, verbose = FALSE)
    pred <- stats::predict(fit, newdata = test_lag_df, n.trees = 100)
    return(as.numeric(pred))
  }

  stop(sprintf("Unsupported timeseries model: %s", model_name))
}
