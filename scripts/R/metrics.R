safe_div <- function(a, b) ifelse(b == 0, NA_real_, a / b)

classification_metrics <- function(y_true, y_pred, y_prob = NULL) {
  if (is.factor(y_true)) {
    y_true_int <- as.integer(y_true) - 1
  } else {
    y_true_int <- as.integer(as.character(y_true))
  }
  
  if (is.factor(y_pred)) {
    y_pred_int <- as.integer(y_pred) - 1
  } else {
    y_pred_int <- as.integer(as.character(y_pred))
  }
  
  n_classes <- length(unique(c(y_true_int, y_pred_int)))
  is_binary <- n_classes == 2
  
  if (is_binary) {
    tp <- sum(y_true_int == 1 & y_pred_int == 1)
    tn <- sum(y_true_int == 0 & y_pred_int == 0)
    fp <- sum(y_true_int == 0 & y_pred_int == 1)
    fn <- sum(y_true_int == 1 & y_pred_int == 0)
    
    precision <- safe_div(tp, tp + fp)
    recall <- safe_div(tp, tp + fn)
    f1 <- ifelse(is.na(precision) || is.na(recall) || (precision + recall) == 0, NA_real_, 2 * precision * recall / (precision + recall))
    acc <- safe_div(tp + tn, length(y_true_int))
    
    out <- list(
      accuracy = acc,
      precision = precision,
      recall = recall,
      f1 = f1
    )
    
    if (!is.null(y_prob) && length(y_prob) == length(y_true_int)) {
      eps <- 1e-15
      p <- pmin(pmax(y_prob, eps), 1 - eps)
      out$logloss <- -mean(y_true_int * log(p) + (1 - y_true_int) * log(1 - p))
      if (requireNamespace("pROC", quietly = TRUE)) {
        tryCatch({
          roc_obj <- pROC::roc(y_true_int, y_prob, quiet = TRUE)
          out$roc_auc <- as.numeric(pROC::auc(roc_obj))
        }, error = function(e) {
          out$roc_auc <- NA_real_
        })
      } else {
        out$roc_auc <- NA_real_
      }
    } else {
      out$logloss <- NA_real_
      out$roc_auc <- NA_real_
    }
  } else {
    classes <- as.character(unique(c(y_true_int, y_pred_int)))
    n_classes <- length(classes)
    precisions <- numeric(n_classes)
    recalls <- numeric(n_classes)
    f1s <- numeric(n_classes)
    
    for (i in seq_along(classes)) {
      cls <- classes[i]
      tp <- sum(y_true_int == cls & y_pred_int == cls)
      fp <- sum(y_true_int != cls & y_pred_int == cls)
      fn <- sum(y_true_int == cls & y_pred_int != cls)
      
      precisions[i] <- safe_div(tp, tp + fp)
      recalls[i] <- safe_div(tp, tp + fn)
      f1s[i] <- ifelse(is.na(precisions[i]) || is.na(recalls[i]) || (precisions[i] + recalls[i]) == 0, NA_real_, 2 * precisions[i] * recalls[i] / (precisions[i] + recalls[i]))
    }
    
    out <- list(
      accuracy = mean(y_true_int == y_pred_int),
      precision = mean(precisions, na.rm = TRUE),
      recall = mean(recalls, na.rm = TRUE),
      f1 = mean(f1s, na.rm = TRUE)
    )
    
    if (!is.null(y_prob) && is.matrix(y_prob) && nrow(y_prob) == length(y_true_int)) {
      eps <- 1e-15
      y_prob <- pmin(pmax(y_prob, eps), 1 - eps)
      true_matrix <- model.matrix(~ factor(y_true_int) - 1)
      out$logloss <- -mean(rowSums(true_matrix * log(y_prob)))
      if (requireNamespace("pROC", quietly = TRUE)) {
        tryCatch({
          roc_obj <- pROC::multiclass.roc(y_true_int, y_prob, quiet = TRUE)
          out$roc_auc <- as.numeric(pROC::auc(roc_obj))
        }, error = function(e) {
          out$roc_auc <- NA_real_
        })
      } else {
        out$roc_auc <- NA_real_
      }
    } else {
      out$logloss <- NA_real_
      out$roc_auc <- NA_real_
    }
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
