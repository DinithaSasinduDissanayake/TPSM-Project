safe_div <- function(a, b) ifelse(b == 0, NA_real_, a / b)

classification_metrics <- function(y_true, y_pred, y_prob = NULL) {
  y_true <- as.integer(as.factor(y_true)) - 1
  y_pred <- as.integer(as.factor(y_pred)) - 1

  tp <- sum(y_true == 1 & y_pred == 1)
  tn <- sum(y_true == 0 & y_pred == 0)
  fp <- sum(y_true == 0 & y_pred == 1)
  fn <- sum(y_true == 1 & y_pred == 0)

  precision <- safe_div(tp, tp + fp)
  recall <- safe_div(tp, tp + fn)
  f1 <- ifelse(is.na(precision) || is.na(recall) || (precision + recall) == 0, NA_real_, 2 * precision * recall / (precision + recall))
  acc <- safe_div(tp + tn, length(y_true))

  out <- list(
    accuracy = acc,
    precision = precision,
    recall = recall,
    f1 = f1
  )

  if (!is.null(y_prob)) {
    eps <- 1e-15
    p <- pmin(pmax(y_prob, eps), 1 - eps)
    out$logloss <- -mean(y_true * log(p) + (1 - y_true) * log(1 - p))
    if (requireNamespace("pROC", quietly = TRUE)) {
      roc_obj <- pROC::roc(y_true, y_prob, quiet = TRUE)
      out$roc_auc <- as.numeric(pROC::auc(roc_obj))
    } else {
      out$roc_auc <- NA_real_
    }
  } else {
    out$logloss <- NA_real_
    out$roc_auc <- NA_real_
  }
  out
}

regression_metrics <- function(y_true, y_pred) {
  err <- y_true - y_pred
  rmse <- sqrt(mean(err^2, na.rm = TRUE))
  mae <- mean(abs(err), na.rm = TRUE)
  ss_res <- sum(err^2, na.rm = TRUE)
  ss_tot <- sum((y_true - mean(y_true, na.rm = TRUE))^2, na.rm = TRUE)
  r2 <- ifelse(ss_tot == 0, NA_real_, 1 - ss_res / ss_tot)
  mape <- mean(abs(safe_div(err, y_true)), na.rm = TRUE) * 100
  list(rmse = rmse, mae = mae, r2 = r2, mape = mape)
}

timeseries_metrics <- function(y_true, y_pred) {
  base <- regression_metrics(y_true, y_pred)
  smape <- mean(200 * abs(y_pred - y_true) / (abs(y_true) + abs(y_pred)), na.rm = TRUE)
  base$smape <- smape
  base
}

is_higher_better <- function(metric_name) {
  metric_name %in% c("accuracy", "precision", "recall", "f1", "roc_auc", "r2")
}
