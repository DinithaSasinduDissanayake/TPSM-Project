make_lag_matrix <- function(y, max_lag = 12, exog = NULL, exog_max_lag = 6) {
  n <- length(y)
  out <- data.frame(target = y)
  for (l in seq_len(max_lag)) {
    out[[paste0("lag_", l)]] <- dplyr::lag(y, l)
  }
  if (!is.null(exog) && is.data.frame(exog)) {
    for (col in names(exog)) {
      for (l in seq_len(exog_max_lag)) {
        out[[paste0(col, "_lag_", l)]] <- dplyr::lag(exog[[col]], l)
      }
    }
  }
  stats::na.omit(out)
}

parse_time_column <- function(df, time_col) {
  if (is.null(time_col) || !time_col %in% names(df)) {
    return(df)
  }
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
    df[[time_col]] <- NULL
    df$day_of_week <- as.integer(format(parsed, "%w"))
    df$month <- as.integer(format(parsed, "%m"))
    df$hour_of_day <- as.integer(format(parsed, "%H"))
    df$day_of_year <- as.integer(format(parsed, "%j"))
  }
  df
}

train_predict_timeseries <- function(model_name, y_train, y_test, lag = 12, exog_train = NULL, exog_test = NULL) {
  if (model_name == "arima") {
    best_aic <- Inf
    best_order <- c(1, 1, 1)
    for (p in 0:2) {
      for (d in 0:1) {
        for (q in 0:2) {
          tryCatch({
            fit <- stats::arima(y_train, order = c(p, d, q), method = "ML")
            if (!is.na(fit$aic) && fit$aic < best_aic) {
              best_aic <- fit$aic
              best_order <- c(p, d, q)
            }
          }, error = function(e) {})
        }
      }
    }
    fit <- stats::arima(y_train, order = best_order, method = "ML")
    fc <- stats::predict(fit, n.ahead = length(y_test))$pred
    return(as.numeric(fc))
  }

  if (model_name == "exp_smoothing") {
    y_ts <- stats::ts(y_train)
    alpha <- 0.3
    best_sse <- Inf
    for (a in c(0.1, 0.2, 0.3, 0.4, 0.5)) {
      tryCatch({
        fit <- stats::HoltWinters(y_ts, alpha = a, beta = FALSE, gamma = FALSE, opt.crit = "rmse")
        fitted_vals <- stats::fitted(fit)
        sse <- sum((fitted_vals - y_train)^2, na.rm = TRUE)
        if (sse < best_sse) {
          best_sse <- sse
          alpha <- a
        }
      }, error = function(e) {})
    }
    fit <- stats::HoltWinters(y_ts, alpha = alpha, beta = FALSE, gamma = FALSE)
    fc <- stats::predict(fit, n.ahead = length(y_test))
    return(as.numeric(fc))
  }

  full_y <- c(y_train, y_test)
  full_exog <- NULL
  if (!is.null(exog_train) && !is.null(exog_test)) {
    full_exog <- rbind(exog_train, exog_test)
  }
  
  lag_df <- make_lag_matrix(full_y, max_lag = lag, exog = full_exog, exog_max_lag = 6)
  split_point <- length(y_train) - lag
  if (split_point <= 0) stop("Not enough training data for lagged model")
  
  train_df <- lag_df[seq_len(split_point), , drop = FALSE]
  test_df <- lag_df[(split_point + 1):nrow(lag_df), , drop = FALSE]

  x_train <- as.matrix(train_df[, setdiff(names(train_df), "target"), drop = FALSE])
  y_train_lag <- train_df$target
  x_test <- as.matrix(test_df[, setdiff(names(test_df), "target"), drop = FALSE])

  if (model_name == "gbm_lag") {
    if (!requireNamespace("gbm", quietly = TRUE)) stop("Package 'gbm' required")
    train_lag_df <- data.frame(target = y_train_lag, x_train)
    test_lag_df <- data.frame(x_test)
    col_names <- c("target", paste0("x", seq_len(ncol(x_train))))
    names(train_lag_df) <- col_names
    names(test_lag_df) <- paste0("x", seq_len(ncol(x_test)))
    fit <- gbm::gbm(target ~ ., data = train_lag_df, distribution = "gaussian", n.trees = 100, interaction.depth = 3, shrinkage = 0.05, n.minobsinnode = 10, verbose = FALSE)
    pred <- stats::predict(fit, newdata = test_lag_df, n.trees = 100)
    return(as.numeric(pred))
  }

  stop(sprintf("Unsupported timeseries model: %s", model_name))
}
