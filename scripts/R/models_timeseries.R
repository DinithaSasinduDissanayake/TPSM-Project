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
    if (inherits(parsed, "POSIXct")) {
      df$hour_of_day <- as.integer(format(parsed, "%H"))
    }
    df$day_of_year <- as.integer(format(parsed, "%j"))
  }
  df
}

train_predict_timeseries <- function(model_name, y_train, y_test, lag = 12, exog_train = NULL, exog_test = NULL) {
  if (model_name == "arima") {
    best_aic <- Inf
    best_order <- c(1, 1, 1)

    # Use ARIMAX if exogenous variables and forecast package available
    has_exog <- !is.null(exog_train) && !is.null(exog_test)
    use_arimax <- has_exog && requireNamespace("forecast", quietly = TRUE)

    if (use_arimax) {
      # ARIMAX grid search with exogenous regressors
      # Note: forecast::Arima automatically handles differencing with xreg alignment
      for (p in 0:2) {
        for (d in 0:1) {
          for (q in 0:2) {
            tryCatch({
              fit <- forecast::Arima(y_train, order = c(p, d, q), xreg = exog_train)
              if (!is.na(fit$aic) && fit$aic < best_aic) {
                best_aic <- fit$aic
                best_order <- c(p, d, q)
              }
            }, error = function(e) {})
          }
        }
      }
      # Warning if all grid search orders failed (M5)
      if (best_aic == Inf) {
        warning(sprintf(
          "All ARIMAX orders failed during grid search. Falling back to default order (1,1,1). %s",
          "This may indicate non-stationary data or numerical issues."
        ))
      }
      # Fit best ARIMAX model and forecast with exogenous test data
      fit <- forecast::Arima(y_train, order = best_order, xreg = exog_train)
      fc <- forecast::forecast(fit, h = length(y_test), xreg = exog_test)$mean
      return(as.numeric(fc))
    } else {
      # Standard ARIMA without exogenous variables
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
      # Warning if all grid search orders failed (M5)
      if (best_aic == Inf) {
        warning(sprintf(
          "All ARIMA orders failed during grid search. Falling back to default order (1,1,1). %s",
          "This may indicate non-stationary data or numerical issues."
        ))
      }
      fit <- stats::arima(y_train, order = best_order, method = "ML")
      fc <- stats::predict(fit, n.ahead = length(y_test))$pred
      return(as.numeric(fc))
    }
  }

  if (model_name == "exp_smoothing") {
    y_ts <- stats::ts(y_train)
    alpha <- 0.3
    best_sse <- Inf
    for (a in c(0.1, 0.2, 0.3, 0.4, 0.5)) {
      tryCatch({
        fit <- stats::HoltWinters(y_ts, alpha = a, beta = FALSE, gamma = FALSE, opt.crit = "rmse")
        fitted_vals <- stats::fitted(fit)[, "xhat"]
        n_fitted <- length(fitted_vals)
        y_train_tail <- y_train[(length(y_train) - n_fitted + 1):length(y_train)]
        sse <- sum((fitted_vals - y_train_tail)^2, na.rm = TRUE)
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
  min_train_rows <- max(30, lag * 2)
  if (split_point <= 0) stop("Not enough training data for lagged model")
  if (split_point < min_train_rows) {
    stop(sprintf(
      "Not enough training data for lagged model: %d rows after lag removal (need >= %d)",
      split_point, min_train_rows
    ))
  }
  
  train_df <- lag_df[seq_len(split_point), , drop = FALSE]
  test_df <- lag_df[(split_point + 1):nrow(lag_df), , drop = FALSE]

  x_train <- as.matrix(train_df[, setdiff(names(train_df), "target"), drop = FALSE])
  y_train_lag <- train_df$target
  x_test <- as.matrix(test_df[, setdiff(names(test_df), "target"), drop = FALSE])

  if (model_name == "gbm_lag") {
    if (!requireNamespace("gbm", quietly = TRUE)) stop("Package 'gbm' required")

    # Build lag matrix ONLY from training data (no data leakage)
    lag_df_train <- make_lag_matrix(y_train, max_lag = lag, exog = exog_train, exog_max_lag = 6)
    lag_df_train <- na.omit(lag_df_train)

    # Ensure enough training data after lag removal
    min_train_rows <- max(30, lag * 2)
    if (nrow(lag_df_train) < min_train_rows) {
      stop(sprintf(
        "Not enough training data for lagged model: %d rows (need >= %d)",
        nrow(lag_df_train), min_train_rows
      ))
    }

    # Fit model on training lags only
    x_train <- as.matrix(lag_df_train[, setdiff(names(lag_df_train), "target"), drop = FALSE])
    y_train_lag <- lag_df_train$target
    train_lag_df <- data.frame(target = y_train_lag, x_train)

    col_names <- c("target", paste0("x", seq_len(ncol(x_train))))
    names(train_lag_df) <- col_names

    fit <- gbm::gbm(target ~ ., data = train_lag_df, distribution = "gaussian",
                     n.trees = 100, interaction.depth = 3, shrinkage = 0.05,
                     n.minobsinnode = 10, verbose = FALSE)

    # Recursive forecasting - predict one step at a time to match ARIMA/exp_smoothing
    preds <- numeric(length(y_test))
    current_y <- y_train
    current_exog_train <- exog_train
    current_exog_test <- if (!is.null(exog_test)) exog_test else NULL

    for (i in seq_along(y_test)) {
      # Build lag matrix from current history (train + previous predictions)
      # For exog: use test row for current step, combine with training exog
      exog_for_step <- NULL
      if (!is.null(current_exog_test)) {
        exog_for_step <- rbind(current_exog_train, current_exog_test[1:i, , drop = FALSE])
      }
      lag_df_step <- make_lag_matrix(current_y, max_lag = lag, exog = exog_for_step, exog_max_lag = 6)
      lag_df_step <- na.omit(lag_df_step)

      # Get features for prediction (last row after lag removal)
      x_step <- as.matrix(lag_df_step[nrow(lag_df_step), setdiff(names(lag_df_step), "target"), drop = FALSE])
      test_lag_df <- data.frame(x_step)
      names(test_lag_df) <- paste0("x", seq_len(ncol(x_step)))

      # Predict this step
      preds[i] <- gbm::predict(fit, newdata = test_lag_df, n.trees = 100)

      # Update history with prediction (use prediction as lag for next step)
      current_y <- c(current_y, preds[i])
    }

    return(as.numeric(preds))
  }

  stop(sprintf("Unsupported timeseries model: %s", model_name))
}
